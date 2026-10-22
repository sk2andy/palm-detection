import Testing

@testable import PalmGuardCore

@Suite("Pointer sequence ownership")
struct PointerSequenceFilterTests {
    @Test func externalMouseIsIndependentOfBlockedTrackpad() {
        var filter = PointerSequenceFilter()
        #expect(
            filter.shouldSuppress(
                phase: .down, senderID: 11, button: 0,
                eventNumber: 100, blockNewPress: true) == true)
        #expect(filter.shouldSuppress(phase: .down, senderID: 22, button: 0, eventNumber: 200) == false)
        #expect(filter.shouldSuppress(phase: .drag, senderID: 22, button: 0, eventNumber: 200) == false)
        #expect(filter.shouldSuppress(phase: .up, senderID: 22, button: 0, eventNumber: 200) == false)
        #expect(filter.shouldSuppress(phase: .drag, senderID: 11, button: 0, eventNumber: 0) == true)
        #expect(filter.shouldSuppress(phase: .up, senderID: 11, button: 0, eventNumber: 100) == true)
        #expect(filter.shouldSuppress(phase: .drag, senderID: 11, button: 0, eventNumber: 0) == false)
    }

    @Test func otherButtonAndUnmatchedReleasePass() {
        var filter = PointerSequenceFilter()
        #expect(
            filter.shouldSuppress(
                phase: .down, senderID: 11, button: 0,
                eventNumber: 100, blockNewPress: true) == true)
        #expect(filter.shouldSuppress(phase: .up, senderID: 11, button: 1, eventNumber: 100) == false)
        #expect(filter.shouldSuppress(phase: .up, senderID: 11, button: 0, eventNumber: 99) == false)
        #expect(filter.shouldSuppress(phase: .up, senderID: 11, button: 0, eventNumber: 100) == true)
    }

    @Test func unknownSenderNeverSuppresses() {
        var filter = PointerSequenceFilter()
        #expect(
            filter.shouldSuppress(
                phase: .down, senderID: 0, button: 0,
                eventNumber: 100, blockNewPress: true) == false)
        #expect(filter.shouldSuppress(phase: .up, senderID: 0, button: 0, eventNumber: 100) == false)
    }

    @Test func newAllowedPressClearsLostRelease() {
        var filter = PointerSequenceFilter()
        #expect(
            filter.shouldSuppress(
                phase: .down, senderID: 11, button: 0,
                eventNumber: 100, blockNewPress: true) == true)
        #expect(filter.shouldSuppress(phase: .down, senderID: 11, button: 0, eventNumber: 101) == false)
        #expect(filter.shouldSuppress(phase: .drag, senderID: 11, button: 0, eventNumber: 0) == false)
        #expect(filter.shouldSuppress(phase: .up, senderID: 11, button: 0, eventNumber: 101) == false)
    }

    @Test func disabledStreamDoesNotRetainSuppression() {
        var filter = PointerSequenceFilter()
        #expect(
            filter.shouldSuppress(
                phase: .down, senderID: 11, button: 0,
                eventNumber: 100, blockNewPress: true) == true)
        filter.reset()
        #expect(filter.shouldSuppress(phase: .up, senderID: 11, button: 0, eventNumber: 100) == false)
    }
}
