import Testing

@testable import PalmGuardCore

@Suite("Palm filtering integration")
struct PalmGestureEngineTests {
    private let wrist = TouchContact(id: 10, position: TouchPoint(x: 0.05, y: 0.05), size: 3)
    private let finger = TouchContact(id: 1, position: TouchPoint(x: 0.5, y: 0.5), size: 1)

    private func readyEngine() -> PalmGestureEngine {
        var engine = PalmGestureEngine()
        _ = engine.process(contacts: [], timestamp: 0)
        return engine
    }

    @Test func wristAloneBlocksClickWhileFreshAndBrieflyAfterLift() {
        var engine = readyEngine()
        _ = engine.process(contacts: [wrist], timestamp: 0.01)
        #expect(engine.shouldBlockClick(at: 0.02))
        _ = engine.process(contacts: [], timestamp: 0.05)
        #expect(engine.shouldBlockClick(at: 0.06))
        _ = engine.process(contacts: [], timestamp: 0.10)
        #expect(!engine.shouldBlockClick(at: 0.21))
    }

    @Test(arguments: [1, 2])
    func restingWristDoesNotPoisonIntentionalFingers(count: Int) {
        var engine = readyEngine()
        _ = engine.process(contacts: [wrist], timestamp: 0.01)
        var fingers = [finger]
        if count == 2 { fingers.append(TouchContact(id: 2, position: TouchPoint(x: 0.6, y: 0.5), size: 1)) }
        _ = engine.process(contacts: [wrist] + fingers, timestamp: 0.03)
        #expect(!engine.shouldBlockClick(at: 0.04))
        #expect(engine.process(contacts: [wrist], timestamp: 0.09) == .accepted(fingers: count))
        #expect(!engine.shouldBlockClick(at: 0.10))
        _ = engine.process(contacts: [wrist, finger], timestamp: 0.12)
        #expect(!engine.shouldBlockClick(at: 0.13))
        #expect(engine.process(contacts: [wrist], timestamp: 0.18) == .accepted(fingers: 1))
    }

    @Test func ignoredContactSlidingInsideRemainsBlocked() {
        var engine = readyEngine()
        _ = engine.process(contacts: [wrist], timestamp: 0.01)
        let moved = TouchContact(id: 10, position: finger.position, size: 1)
        #expect(engine.process(contacts: [moved], timestamp: 0.04) == nil)
        #expect(engine.shouldBlockClick(at: 0.05))
        #expect(engine.process(contacts: [], timestamp: 0.08) == nil)
    }

    @Test func acceptedReleaseAllowsNativeClickBesideWristOnlyBriefly() {
        var engine = readyEngine()
        _ = engine.process(contacts: [wrist], timestamp: 0.01)
        _ = engine.process(contacts: [wrist, finger], timestamp: 0.03)
        #expect(engine.process(contacts: [wrist], timestamp: 0.09) == .accepted(fingers: 1))
        #expect(!engine.shouldBlockClick(at: 0.10))
        _ = engine.process(contacts: [wrist], timestamp: 0.18)
        _ = engine.process(contacts: [wrist], timestamp: 0.25)
        #expect(engine.shouldBlockClick(at: 0.26))
    }

    @Test func leavingAreaCancelsTapAndBlocksClickAfterRelease() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger], timestamp: 0.01)
        let outside = TouchContact(id: 1, position: wrist.position, size: 1)
        #expect(engine.process(contacts: [outside], timestamp: 0.04) == .rejected(reason: .cancelled))
        #expect(engine.shouldBlockClick(at: 0.05))
        _ = engine.process(contacts: [], timestamp: 0.08)
        #expect(engine.shouldBlockClick(at: 0.09))
        _ = engine.process(contacts: [finger], timestamp: 0.11)
        #expect(!engine.shouldBlockClick(at: 0.12))
    }

    @Test func oneFingerLeavingInvalidatesRemainingFingerUntilLift() {
        var engine = readyEngine()
        let second = TouchContact(id: 2, position: TouchPoint(x: 0.6, y: 0.5), size: 1)
        _ = engine.process(contacts: [finger, second], timestamp: 0.01)
        let outside = TouchContact(id: 1, position: wrist.position, size: 1)
        _ = engine.process(contacts: [outside, second], timestamp: 0.04)
        #expect(engine.shouldBlockClick(at: 0.05))
        #expect(engine.process(contacts: [outside], timestamp: 0.08) == .rejected(reason: .cancelled))
        #expect(engine.shouldBlockClick(at: 0.09))
    }

    @Test func malformedAndDuplicateRawDataFailOpen() {
        var engine = readyEngine()
        _ = engine.process(contacts: [wrist], timestamp: 0.01)
        #expect(engine.process(contacts: [wrist, wrist], timestamp: 0.02) == .rejected(reason: .invalidData))
        #expect(!engine.shouldBlockClick(at: 0.03))
        _ = engine.process(contacts: [], timestamp: 0.04)
        let invalid = TouchContact(id: 10, position: TouchPoint(x: .nan, y: 0.5), size: 1)
        #expect(engine.process(contacts: [invalid], timestamp: 0.05) == .rejected(reason: .invalidData))
        #expect(!engine.shouldBlockClick(at: 0.06))
    }

    @Test func staleAndInterruptedDataFailOpen() {
        var engine = readyEngine()
        _ = engine.process(contacts: [wrist], timestamp: 0.01)
        #expect(!engine.shouldBlockClick(at: 0.17))
        #expect(engine.process(contacts: [wrist], timestamp: 0.20) == .rejected(reason: .interrupted))
        #expect(!engine.shouldBlockClick(at: 0.21))
    }

    @Test func startupRequiresRawEmptyFrameBeforeBlocking() {
        var engine = PalmGestureEngine()
        _ = engine.process(contacts: [wrist], timestamp: 0.01)
        #expect(!engine.shouldBlockClick(at: 0.02))
        _ = engine.process(contacts: [], timestamp: 0.04)
        _ = engine.process(contacts: [wrist], timestamp: 0.06)
        #expect(engine.shouldBlockClick(at: 0.07))
    }

    @Test func physicalClickCancelsSyntheticTapWithoutBlockingValidContact() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger], timestamp: 0.01)
        engine.cancelCurrentGesture()
        #expect(!engine.shouldBlockClick(at: 0.02))
        #expect(engine.process(contacts: [], timestamp: 0.08) == .rejected(reason: .cancelled))
        #expect(!engine.shouldBlockClick(at: 0.09))
    }

    @Test func movingThenHoldingFingerStillAllowsNativePressureClick() {
        var engine = readyEngine()
        _ = engine.process(contacts: [finger], timestamp: 0.01)
        let moved = TouchContact(id: 1, position: TouchPoint(x: 0.7, y: 0.5), size: 1)
        for timestamp in [0.05, 0.15, 0.25, 0.35] {
            _ = engine.process(contacts: [moved], timestamp: timestamp)
        }
        #expect(!engine.shouldBlockClick(at: 0.36))
        #expect(engine.process(contacts: [], timestamp: 0.38) == .rejected(reason: .tooMuchMovement))
        #expect(engine.shouldBlockClick(at: 0.39))
    }
}
