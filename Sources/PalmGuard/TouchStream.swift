import Foundation
import MultitouchBridge
import PalmGuardCore

struct ContactFrame: Sendable {
    let contacts: [TouchContact]
    let receivedAt: TimeInterval
    let generation: UUID
}

/// The C bridge holds this object only until stop's callback barrier has completed.
final class FrameContext: Sendable {
    let generation = UUID()
    let receive: @Sendable (ContactFrame) -> Void

    init(receive: @escaping @Sendable (ContactFrame) -> Void) { self.receive = receive }
}

// Keep the C entry point outside MainActor. A closure declared inside start() inherits
// actor isolation and traps when MultitouchSupport calls it on its worker thread.
func receiveMultitouchFrame(
    _ deviceID: UInt64, _ raw: UnsafePointer<PDMTContact>?, _ count: Int,
    _ timestamp: Double, _ opaque: UnsafeMutableRawPointer?
) {
    guard let opaque else { return }
    let context = Unmanaged<FrameContext>.fromOpaque(opaque).takeUnretainedValue()
    let contacts: [TouchContact]
    if let raw {
        contacts = UnsafeBufferPointer(start: raw, count: count)
            .filter { (3...5).contains($0.state) }
            .map {
                TouchContact(
                    id: Int($0.identifier),
                    position: TouchPoint(x: Double($0.x), y: Double($0.y)), size: Double($0.size))
            }
    } else {
        contacts = []
    }
    context.receive(
        ContactFrame(
            contacts: contacts,
            receivedAt: ProcessInfo.processInfo.systemUptime, generation: context.generation))
}

@MainActor
final class TouchStream {
    var onFrame: (([TouchContact], TimeInterval) -> Void)?
    private var context: FrameContext?
    private(set) var deviceName = "Kein externes Trackpad"
    private(set) var deviceID: UInt64 = 0
    private(set) var isRunning = false

    func start() -> String? {
        stop()
        let context = FrameContext { [weak self] frame in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.context?.generation == frame.generation else { return }
                self.onFrame?(frame.contacts, frame.receivedAt)
            }
        }
        self.context = context
        let result = pd_mt_start(false, receiveMultitouchFrame, Unmanaged.passUnretained(context).toOpaque())
        guard result == PDMTStatusOK else {
            self.context = nil
            return String(cString: pd_mt_status_message(result))
        }
        var info = PDMTDeviceInfo()
        if pd_mt_get_info(&info) {
            deviceID = info.registry_id
            deviceName = withUnsafePointer(to: &info.name) {
                $0.withMemoryRebound(to: CChar.self, capacity: 128) { String(cString: $0) }
            }
        }
        isRunning = true
        return nil
    }

    func stop() {
        pd_mt_stop()
        context = nil
        isRunning = false
        deviceID = 0
    }
}
