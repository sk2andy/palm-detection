import Testing

@testable import PalmGuardCore

@Suite("Synthetic taps preserve native gestures")
struct PalmGestureEngineTests {
    private let wrist = TouchContact(id: 10, position: TouchPoint(x: 0.05, y: 0.05), size: 3)
    private let finger = TouchContact(id: 1, position: TouchPoint(x: 0.5, y: 0.5), size: 1)
    private let second = TouchContact(id: 2, position: TouchPoint(x: 0.6, y: 0.5), size: 1)
    private let outside = TouchContact(id: 3, position: TouchPoint(x: 0.05, y: 0.5), size: 1)

    private func readyEngine() -> PalmGestureEngine {
        var engine = PalmGestureEngine()
        _ = engine.process(contacts: [], timestamp: 0)
        return engine
    }

    @Test(arguments: [1, 2])
    func acceptsNormalTaps(count: Int) {
        var engine = readyEngine()
        _ = engine.process(contacts: count == 1 ? [finger] : [finger, second], timestamp: 0.01)
        #expect(engine.process(contacts: [], timestamp: 0.08) == .accepted(fingers: count))
    }

    @Test(arguments: [1, 2])
    func broadRestingWristDoesNotPoisonIntentionalFingers(count: Int) {
        var engine = readyEngine()
        _ = engine.process(contacts: [wrist], timestamp: 0.01)
        _ = engine.process(contacts: count == 1 ? [wrist, finger] : [wrist, finger, second], timestamp: 0.03)
        #expect(engine.process(contacts: [wrist], timestamp: 0.09) == .accepted(fingers: count))
        _ = engine.process(contacts: [wrist, finger], timestamp: 0.12)
        #expect(engine.process(contacts: [wrist], timestamp: 0.18) == .accepted(fingers: 1))
    }

    @Test func wristAloneNeverProducesTap() {
        var engine = readyEngine()
        #expect(engine.process(contacts: [wrist], timestamp: 0.01) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.08) == nil)
    }

    @Test func shortStationaryThreeFingersWithOneOutsideCannotBecomeTwoFingerTap() {
        var engine = readyEngine()
        #expect(
            engine.process(contacts: [finger, second, outside], timestamp: 0.01) == .rejected(reason: .tooManyFingers))
        #expect(engine.process(contacts: [], timestamp: 0.08) == nil)
    }

    @Test func movingThreeFingerDragWithOneOutsideNeverProducesTap() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger, second, outside], timestamp: 0.01)
        let moved = TouchContact(id: 1, position: TouchPoint(x: 0.7, y: 0.5), size: 1)
        #expect(engine.process(contacts: [moved, second, outside], timestamp: 0.05) == nil)
        #expect(engine.process(contacts: [moved, second], timestamp: 0.09) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.12) == nil)
    }

    @Test func outsideThirdFingerJoiningExistingCandidateCancelsIt() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger, second], timestamp: 0.01)
        #expect(
            engine.process(contacts: [finger, second, outside], timestamp: 0.03) == .rejected(reason: .tooManyFingers))
        #expect(engine.process(contacts: [finger, second], timestamp: 0.05) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.08) == nil)
    }

    @Test func staggeredThreeFingerReleaseCannotCreateSubsetTap() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger, second, outside], timestamp: 0.01)
        #expect(engine.process(contacts: [finger, second], timestamp: 0.03) == nil)
        #expect(engine.process(contacts: [finger], timestamp: 0.05) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.08) == nil)
        _ = engine.process(contacts: [finger], timestamp: 0.10)
        #expect(engine.process(contacts: [], timestamp: 0.16) == .accepted(fingers: 1))
    }

    @Test func outsideFingerRemainingKeepsVetoForNewInsideFingers() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger, second, outside], timestamp: 0.01)
        #expect(engine.process(contacts: [outside], timestamp: 0.03) == nil)
        #expect(engine.process(contacts: [finger, outside], timestamp: 0.05) == nil)
        #expect(engine.process(contacts: [finger], timestamp: 0.07) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.10) == nil)
    }

    @Test func broadPalmCanRemainWhenNativeGestureVetoEnds() {
        var engine = readyEngine()
        _ = engine.process(contacts: [wrist, finger, second, outside], timestamp: 0.01)
        #expect(engine.process(contacts: [wrist], timestamp: 0.05) == nil)
        _ = engine.process(contacts: [wrist, finger, second], timestamp: 0.07)
        #expect(engine.process(contacts: [wrist], timestamp: 0.13) == .accepted(fingers: 2))
    }

    @Test func fingerGrowingBroadDoesNotCountAsLiftDuringNativeGesture() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger, second, outside], timestamp: 0.01)
        let broadThird = TouchContact(id: 3, position: outside.position, size: 3)
        #expect(engine.process(contacts: [broadThird], timestamp: 0.04) == nil)
        #expect(engine.process(contacts: [finger, broadThird], timestamp: 0.06) == nil)
        #expect(engine.process(contacts: [broadThird], timestamp: 0.10) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.12) == nil)
        _ = engine.process(contacts: [finger], timestamp: 0.14)
        #expect(engine.process(contacts: [], timestamp: 0.20) == .accepted(fingers: 1))
    }

    @Test func ignoredContactSlidingInsideNeverBecomesTap() {
        var engine = readyEngine()
        _ = engine.process(contacts: [outside], timestamp: 0.01)
        let moved = TouchContact(id: 3, position: finger.position, size: 1)
        #expect(engine.process(contacts: [moved], timestamp: 0.04) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.08) == nil)
    }

    @Test func leavingAreaCancelsTapBeforeFalseRelease() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger], timestamp: 0.01)
        let moved = TouchContact(id: 1, position: outside.position, size: 1)
        #expect(engine.process(contacts: [moved], timestamp: 0.04) == .rejected(reason: .cancelled))
        #expect(engine.process(contacts: [], timestamp: 0.08) == nil)
    }

    @Test func oneFingerLeavingInvalidatesRemainingFingerUntilLift() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger, second], timestamp: 0.01)
        let moved = TouchContact(id: 1, position: outside.position, size: 1)
        _ = engine.process(contacts: [moved, second], timestamp: 0.04)
        #expect(engine.process(contacts: [moved], timestamp: 0.08) == .rejected(reason: .cancelled))
    }

    @Test func malformedDataCancelsCandidateAndRequiresAllFingersReleased() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger], timestamp: 0.01)
        let invalid = TouchContact(id: 1, position: TouchPoint(x: .nan, y: 0.5), size: 1)
        #expect(engine.process(contacts: [invalid], timestamp: 0.03) == .rejected(reason: .invalidData))
        #expect(engine.process(contacts: [finger], timestamp: 0.05) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.08) == .rejected(reason: .notReady))
        _ = engine.process(contacts: [finger], timestamp: 0.10)
        #expect(engine.process(contacts: [], timestamp: 0.16) == .accepted(fingers: 1))
    }

    @Test func duplicateIDsCannotProduceTap() {
        var engine = readyEngine()
        #expect(engine.process(contacts: [finger, finger], timestamp: 0.01) == .rejected(reason: .invalidData))
        #expect(engine.process(contacts: [], timestamp: 0.08) == nil)
    }

    @Test func interruptedNativeGestureCannotBecomeSubsetTap() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger, second, outside], timestamp: 0.01)
        #expect(engine.process(contacts: [finger], timestamp: 0.20) == .rejected(reason: .interrupted))
        #expect(engine.process(contacts: [finger], timestamp: 0.22) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.26) == .rejected(reason: .notReady))
        _ = engine.process(contacts: [finger], timestamp: 0.28)
        #expect(engine.process(contacts: [], timestamp: 0.34) == .accepted(fingers: 1))
    }

    @Test func startupRequiresFingerReleaseButBroadPalmMayStay() {
        var engine = PalmGestureEngine()
        _ = engine.process(contacts: [wrist, finger], timestamp: 0.01)
        #expect(engine.process(contacts: [wrist], timestamp: 0.08) == .rejected(reason: .notReady))
        _ = engine.process(contacts: [wrist, finger], timestamp: 0.10)
        #expect(engine.process(contacts: [wrist], timestamp: 0.16) == .accepted(fingers: 1))
    }

    @Test func broadPalmPresentAtStartupCannotShrinkIntoTap() {
        var engine = PalmGestureEngine()
        let broad = TouchContact(id: 10, position: finger.position, size: 3)
        let narrow = TouchContact(id: 10, position: finger.position, size: 1)
        #expect(engine.process(contacts: [broad], timestamp: 0.01) == nil)
        #expect(engine.process(contacts: [narrow], timestamp: 0.04) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.08) == nil)
    }

    @Test func broadPalmRemainingAfterNativeGestureCannotShrinkIntoTap() {
        var engine = readyEngine()
        let broad = TouchContact(id: 10, position: finger.position, size: 3)
        let narrow = TouchContact(id: 10, position: finger.position, size: 1)
        _ = engine.process(contacts: [broad, finger, second, outside], timestamp: 0.01)
        #expect(engine.process(contacts: [broad], timestamp: 0.04) == nil)
        #expect(engine.process(contacts: [narrow], timestamp: 0.06) == nil)
        #expect(engine.process(contacts: [], timestamp: 0.10) == nil)
    }

    @Test func physicalActivityCancelsSyntheticTap() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger], timestamp: 0.01)
        engine.cancelCurrentGesture()
        #expect(engine.process(contacts: [], timestamp: 0.08) == .rejected(reason: .cancelled))
    }

    @Test func configurationChangeRequiresReleaseBeforeNewTap() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger], timestamp: 0.01)
        engine.configuration.maximumSize = 2
        _ = engine.process(contacts: [finger], timestamp: 0.03)
        #expect(engine.process(contacts: [], timestamp: 0.08) == .rejected(reason: .notReady))
    }
}
