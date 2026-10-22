import Testing

@testable import PalmGuardCore

@Suite("Complete tap sequences")
struct TapRecognizerTests {
    private func contact(_ id: Int = 1, x: Double = 0.5, y: Double = 0.5, size: Double = 1) -> TouchContact {
        TouchContact(id: id, position: TouchPoint(x: x, y: y), size: size)
    }

    private func readyRecognizer(configuration: TapConfiguration = TapConfiguration()) -> TapRecognizer {
        var recognizer = TapRecognizer(configuration: configuration)
        _ = recognizer.process(contacts: [], timestamp: 0)
        return recognizer
    }

    @Test func acceptsOneFingerTap() {
        var recognizer = readyRecognizer()
        #expect(recognizer.process(contacts: [contact()], timestamp: 0.01) == nil)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .accepted(fingers: 1))
    }

    @Test func acceptsTwoOverlappingFingersWithStaggeredRelease() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact(), contact(2, x: 0.6)], timestamp: 0.04)
        _ = recognizer.process(contacts: [contact(2, x: 0.6)], timestamp: 0.08)
        #expect(recognizer.process(contacts: [], timestamp: 0.10) == .accepted(fingers: 2))
    }

    @Test func rejectsStartupInMiddleOfTouch() {
        var recognizer = TapRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .notReady))
        _ = recognizer.process(contacts: [contact()], timestamp: 0.15)
        #expect(recognizer.process(contacts: [], timestamp: 0.20) == .accepted(fingers: 1))
    }

    @Test func rejectsOutsideAreaEvenAfterMovingInside() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact(x: 0.1)], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact(x: 0.13)], timestamp: 0.04)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .outsideArea))
    }

    @Test func rejectsLeavingAreaEvenIfReturning() {
        var recognizer = readyRecognizer(configuration: TapConfiguration(maximumMovement: 0.1))
        _ = recognizer.process(contacts: [contact(x: 0.13)], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact(x: 0.1)], timestamp: 0.03)
        _ = recognizer.process(contacts: [contact(x: 0.13)], timestamp: 0.05)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .outsideArea))
    }

    @Test func rejectsBroadContactEvenIfItShrinks() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact(size: 2.5)], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact(size: 1)], timestamp: 0.03)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .contactTooLarge))
    }

    @Test func rejectsMoveAndReturn() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact(x: 0.55)], timestamp: 0.03)
        _ = recognizer.process(contacts: [contact()], timestamp: 0.05)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .tooMuchMovement))
    }

    @Test func rejectsSlowDriftMeasuredFromInitialPosition() {
        var recognizer = readyRecognizer()
        for index in 1...6 {
            _ = recognizer.process(contacts: [contact(x: 0.5 + Double(index) * 0.01)], timestamp: Double(index) * 0.02)
        }
        #expect(recognizer.process(contacts: [], timestamp: 0.14) == .rejected(reason: .tooMuchMovement))
    }

    @Test func rejectsLongRestingHand() {
        var recognizer = readyRecognizer()
        for timestamp in [0.01, 0.10, 0.20, 0.30] {
            _ = recognizer.process(contacts: [contact()], timestamp: timestamp)
        }
        #expect(recognizer.process(contacts: [], timestamp: 0.32) == .rejected(reason: .tooLong))
    }

    @Test func rejectsContactNoiseShorterThanMinimum() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        #expect(recognizer.process(contacts: [], timestamp: 0.015) == .rejected(reason: .tooShort))
    }

    @Test func rejectsThirdFingerEvenWhenItLiftsFirst() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact(), contact(2), contact(3)], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact()], timestamp: 0.04)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .tooManyFingers))
    }

    @Test func rejectsLateSecondFinger() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact(), contact(2)], timestamp: 0.11)
        #expect(recognizer.process(contacts: [], timestamp: 0.15) == .rejected(reason: .fingersTooFarApartInTime))
    }

    @Test func rejectsReplacementWithoutOverlap() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact(2)], timestamp: 0.04)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .fingerReplacement))
    }

    @Test func rejectsReturningFinger() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact(), contact(2)], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact()], timestamp: 0.03)
        _ = recognizer.process(contacts: [contact(), contact(2)], timestamp: 0.05)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .fingerReplacement))
    }

    @Test func rejectsDuplicateIdentifiers() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact(), contact()], timestamp: 0.01)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .invalidData))
    }

    @Test(arguments: [Double.nan, .infinity, -0.1, 1.1])
    func rejectsInvalidPosition(value: Double) {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact(x: value)], timestamp: 0.01)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .invalidData))
    }

    @Test(arguments: [Double.nan, .infinity, -0.1])
    func rejectsInvalidSize(value: Double) {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact(size: value)], timestamp: 0.01)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .invalidData))
    }

    @Test func rejectsInvalidTimestampAndRecovers() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        _ = recognizer.process(contacts: [], timestamp: .nan)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .invalidData))
        _ = recognizer.process(contacts: [contact()], timestamp: 0.10)
        #expect(recognizer.process(contacts: [], timestamp: 0.16) == .accepted(fingers: 1))
    }

    @Test(arguments: [0.01, 0.005])
    func rejectsNonIncreasingTime(timestamp: Double) {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        _ = recognizer.process(contacts: [contact()], timestamp: timestamp)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .invalidData))
    }

    @Test func rejectsStaleInputOnRelease() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        #expect(recognizer.process(contacts: [], timestamp: 0.15) == .rejected(reason: .interrupted))
    }

    @Test func physicalClickCancelsCurrentTap() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        recognizer.cancelCurrentGesture()
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .cancelled))
    }

    @Test func cancellationBeforeFirstContactRequiresEmptyFrame() {
        var recognizer = readyRecognizer()
        recognizer.cancelCurrentGesture()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .notReady))
    }

    @Test func resettingOrChangingConfigurationCannotCompleteOldGesture() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.01)
        recognizer.reset()
        _ = recognizer.process(contacts: [contact()], timestamp: 0.03)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .notReady))
        _ = recognizer.process(contacts: [contact()], timestamp: 0.10)
        recognizer.configuration.maximumMovement = 0.03
        _ = recognizer.process(contacts: [contact()], timestamp: 0.12)
        #expect(recognizer.process(contacts: [], timestamp: 0.18) == .rejected(reason: .notReady))
    }

    @Test func independentTapsDoNotShareRejectionState() {
        var recognizer = readyRecognizer()
        _ = recognizer.process(contacts: [contact(x: 0.05)], timestamp: 0.01)
        #expect(recognizer.process(contacts: [], timestamp: 0.08) == .rejected(reason: .outsideArea))
        _ = recognizer.process(contacts: [contact()], timestamp: 0.15)
        #expect(recognizer.process(contacts: [], timestamp: 0.20) == .accepted(fingers: 1))
    }
}
