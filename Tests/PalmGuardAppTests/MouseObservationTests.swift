import CoreGraphics
import Testing

@testable import PalmGuard

@Suite("Native clicks and drags stay untouched")
@MainActor
struct MouseObservationTests {
    @Test func observationCannotSuppressSystemEvents() {
        #expect(MouseEventService.observationOptions == .listenOnly)
        #expect(!MouseEventService.observedEvents.contains(.keyDown))
        #expect(!MouseEventService.observedEvents.contains(.keyUp))
        #expect(!MouseEventService.observedEvents.contains(.flagsChanged))
    }

    @Test func observingPhysicalClicksAndDragsOnlyCancelsTapCandidates() throws {
        let service = MouseEventService()
        var cancellations = 0
        service.onPhysicalActivity = { cancellations += 1 }
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseDragged, .leftMouseUp,
            .rightMouseDown, .rightMouseDragged, .rightMouseUp, .scrollWheel,
        ]
        for type in types {
            let event = try #require(CGEvent(source: nil))
            event.type = type
            event.location = CGPoint(x: 15, y: 900)
            event.flags = [.maskShift, .maskControl]
            let before = event.data
            service.observe(type: type, event: event)
            #expect(event.data == before)
        }
        #expect(cancellations == types.count)
    }

    @Test func ownTapEventsDoNotCancelFollowingDoubleTap() throws {
        let service = MouseEventService()
        var cancellations = 0
        service.onPhysicalActivity = { cancellations += 1 }
        let event = try #require(CGEvent(source: nil))
        event.setIntegerValueField(.eventSourceUserData, value: MouseEventService.eventMarker)
        service.observe(type: .leftMouseDown, event: event)
        service.observe(type: .leftMouseUp, event: event)
        #expect(cancellations == 0)
    }
}
