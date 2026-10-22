import Foundation
import MultitouchBridge
import Testing

@testable import PalmGuard

@Suite("Multitouch callback isolation")
struct TouchStreamTests {
    @Test func acceptsFrameOnBackgroundThread() async {
        let frame: ContactFrame = await withCheckedContinuation { continuation in
            let context = FrameContext { frame in continuation.resume(returning: frame) }
            DispatchQueue.global().async {
                var raw = PDMTContact(
                    identifier: 7, state: 4, x: 0.5, y: 0.25,
                    size: 0.8, major_axis: 1, minor_axis: 1)
                withUnsafePointer(to: &raw) {
                    receiveMultitouchFrame(1, $0, 1, 1, Unmanaged.passUnretained(context).toOpaque())
                }
            }
        }
        #expect(frame.contacts.count == 1)
        #expect(frame.contacts.first?.id == 7)
        #expect(frame.contacts.first?.position.x == 0.5)
        #expect(frame.contacts.first?.position.y == 0.25)
    }

    @Test func liftedContactsBecomeAnEmptyFrame() async {
        let frame: ContactFrame = await withCheckedContinuation { continuation in
            let context = FrameContext { frame in continuation.resume(returning: frame) }
            DispatchQueue.global().async {
                var raw = PDMTContact(
                    identifier: 7, state: 7, x: 0.5, y: 0.25,
                    size: 0.8, major_axis: 1, minor_axis: 1)
                withUnsafePointer(to: &raw) {
                    receiveMultitouchFrame(1, $0, 1, 1, Unmanaged.passUnretained(context).toOpaque())
                }
            }
        }
        #expect(frame.contacts.isEmpty)
    }
}
