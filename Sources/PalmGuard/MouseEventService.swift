import AppKit
import CoreGraphics
import MultitouchBridge
import PalmGuardCore

@MainActor
final class MouseEventService {
    static let eventMarker: Int64 = 0x5041_4C4D
    var shouldBlock: ((Bool) -> Bool)?
    var onPhysicalActivity: (() -> Void)?
    var onTapDisabled: (() -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var sequences = PointerSequenceFilter()
    private var isInvalidating = false
    private var previousClick: (time: TimeInterval, point: CGPoint, button: CGMouseButton, count: Int64)?

    var isRunning: Bool { tap != nil && !isInvalidating }

    func start() -> Bool {
        guard !isInvalidating else { return false }
        if tap != nil { return true }
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .leftMouseDragged, .rightMouseDragged, .scrollWheel,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, context in
                    guard let context else { return Unmanaged.passUnretained(event) }
                    let pass = MainActor.assumeIsolated {
                        let service = Unmanaged<MouseEventService>.fromOpaque(context).takeUnretainedValue()
                        return service.handle(type: type, event: event) != nil
                    }
                    return pass ? Unmanaged.passUnretained(event) : nil
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else { return false }
        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return false
        }
        tap = port
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        if let tap { CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
        sequences.reset()
        previousClick = nil
        isInvalidating = false
    }

    func postTap(fingers: Int) -> Bool {
        guard (1...2).contains(fingers), AXIsProcessTrusted(),
            !CGEventSource.buttonState(.combinedSessionState, button: .left),
            !CGEventSource.buttonState(.combinedSessionState, button: .right),
            let position = CGEvent(source: nil)?.location
        else { return false }
        let button: CGMouseButton = fingers == 1 ? .left : .right
        let downType: CGEventType = fingers == 1 ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = fingers == 1 ? .leftMouseUp : .rightMouseUp
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        eventSource?.localEventsSuppressionInterval = 0
        guard
            let down = CGEvent(
                mouseEventSource: eventSource, mouseType: downType,
                mouseCursorPosition: position, mouseButton: button),
            let up = CGEvent(
                mouseEventSource: eventSource, mouseType: upType,
                mouseCursorPosition: position, mouseButton: button)
        else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        var count: Int64 = 1
        if let previousClick, previousClick.button == button,
            now - previousClick.time < NSEvent.doubleClickInterval,
            hypot(position.x - previousClick.point.x, position.y - previousClick.point.y) < 5
        {
            count = previousClick.count + 1
        }
        previousClick = (now, position, button, count)
        let flags = CGEventSource.flagsState(.combinedSessionState)
        for event in [down, up] {
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
            event.setIntegerValueField(.mouseEventClickState, value: count)
            event.post(tap: .cghidEventTap)
        }
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            guard !isInvalidating else { return Unmanaged.passUnretained(event) }
            sequences.reset()
            isInvalidating = true
            onTapDisabled?()
            // Never fight a permission revocation by re-enabling the tap.
            // Invalidate outside the synchronous WindowServer callback.
            DispatchQueue.main.async { [weak self] in self?.stop() }
            return Unmanaged.passUnretained(event)
        }
        if isInvalidating { return Unmanaged.passUnretained(event) }
        if event.getIntegerValueField(.eventSourceUserData) == Self.eventMarker {
            return Unmanaged.passUnretained(event)
        }
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        let senderID = pd_mt_event_sender_id(event)
        let eventNumber = event.getIntegerValueField(.mouseEventNumber)
        switch type {
        case .leftMouseUp, .rightMouseUp:
            if sequences.shouldSuppress(
                phase: .up, senderID: senderID,
                button: button, eventNumber: eventNumber)
            {
                return nil
            }
        case .leftMouseDragged, .rightMouseDragged:
            if sequences.shouldSuppress(
                phase: .drag, senderID: senderID,
                button: button, eventNumber: eventNumber)
            {
                return nil
            }
        case .leftMouseDown, .rightMouseDown:
            let matches = pd_mt_event_matches_device(event)
            let block = shouldBlock?(matches) ?? false
            onPhysicalActivity?()
            previousClick = nil
            if sequences.shouldSuppress(
                phase: .down, senderID: senderID,
                button: button, eventNumber: eventNumber, blockNewPress: block)
            {
                return nil
            }
        case .scrollWheel:
            onPhysicalActivity?()
        default: break
        }
        return Unmanaged.passUnretained(event)
    }
}
