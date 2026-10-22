import Testing

@testable import PalmGuardCore

@Suite("Independent fingers beside resting palms")
struct PalmContactSelectorTests {
    private let wrist = TouchContact(id: 10, position: TouchPoint(x: 0.05, y: 0.05), size: 3)
    private let finger = TouchContact(id: 1, position: TouchPoint(x: 0.5, y: 0.5), size: 1)

    @Test(arguments: [1, 2])
    func acceptsFingersBesideRestingWrist(fingerCount: Int) {
        var selector = PalmContactSelector()
        var recognizer = TapRecognizer()
        let resting = selector.select(contacts: [wrist], configuration: TapConfiguration())
        #expect(resting.eligible.isEmpty)
        _ = recognizer.process(contacts: resting.eligible, timestamp: 0)
        var fingers = [finger]
        if fingerCount == 2 {
            fingers.append(TouchContact(id: 2, position: TouchPoint(x: 0.6, y: 0.5), size: 1))
        }
        let touching = selector.select(contacts: [wrist] + fingers, configuration: TapConfiguration())
        #expect(touching.eligible.count == fingerCount)
        #expect(touching.ignored == [wrist])
        #expect(!touching.invalidated)
        _ = recognizer.process(contacts: touching.eligible, timestamp: 0.01)
        let released = selector.select(contacts: [wrist], configuration: TapConfiguration())
        #expect(recognizer.process(contacts: released.eligible, timestamp: 0.08) == .accepted(fingers: fingerCount))
    }

    @Test func outsideContactCannotSlideInToBecomeTap() {
        var selector = PalmContactSelector()
        _ = selector.select(contacts: [wrist], configuration: TapConfiguration())
        let insideWrist = TouchContact(id: 10, position: finger.position, size: 1)
        let selection = selector.select(contacts: [insideWrist], configuration: TapConfiguration())
        #expect(selection.eligible.isEmpty)
        #expect(selection.ignored == [insideWrist])
        #expect(!selection.invalidated)
        _ = selector.select(contacts: [], configuration: TapConfiguration())
        #expect(selector.select(contacts: [insideWrist], configuration: TapConfiguration()).eligible == [insideWrist])
    }

    @Test func broadContactCannotShrinkIntoTap() {
        var selector = PalmContactSelector()
        let broad = TouchContact(id: 1, position: finger.position, size: 3)
        _ = selector.select(contacts: [broad], configuration: TapConfiguration())
        #expect(selector.select(contacts: [finger], configuration: TapConfiguration()).eligible.isEmpty)
    }

    @Test func fingerLeavingAreaInvalidatesGestureAndStaysIgnored() {
        var selector = PalmContactSelector()
        _ = selector.select(contacts: [finger], configuration: TapConfiguration())
        let outside = TouchContact(id: 1, position: wrist.position, size: 1)
        let leaving = selector.select(contacts: [outside], configuration: TapConfiguration())
        #expect(leaving.invalidated)
        #expect(leaving.eligible.isEmpty)
        let returning = selector.select(contacts: [finger], configuration: TapConfiguration())
        #expect(returning.eligible.isEmpty)
        #expect(!returning.invalidated)
    }

    @Test func fingerBecomingBroadInvalidatesGesture() {
        var selector = PalmContactSelector()
        _ = selector.select(contacts: [finger], configuration: TapConfiguration())
        let broad = TouchContact(id: 1, position: finger.position, size: 3)
        #expect(selector.select(contacts: [broad], configuration: TapConfiguration()).invalidated)
    }

    @Test func malformedContactInvalidatesAndRemainsIgnoredUntilLift() {
        var selector = PalmContactSelector()
        let invalid = TouchContact(id: 1, position: TouchPoint(x: .nan, y: 0.5), size: 1)
        let selection = selector.select(contacts: [invalid], configuration: TapConfiguration())
        #expect(selection.invalidated)
        #expect(selection.eligible.isEmpty)
        #expect(selector.select(contacts: [finger], configuration: TapConfiguration()).eligible.isEmpty)
    }

    @Test func duplicateIdentifiersInvalidateAllContacts() {
        var selector = PalmContactSelector()
        let selection = selector.select(contacts: [finger, finger], configuration: TapConfiguration())
        #expect(selection.invalidated)
        #expect(selection.eligible.isEmpty)
        #expect(selector.select(contacts: [finger], configuration: TapConfiguration()).eligible.isEmpty)
    }

    @Test func resetDropsIgnoredIdentifiers() {
        var selector = PalmContactSelector()
        _ = selector.select(contacts: [wrist], configuration: TapConfiguration())
        selector.reset()
        let contact = TouchContact(id: 10, position: finger.position, size: 1)
        #expect(selector.select(contacts: [contact], configuration: TapConfiguration()).eligible == [contact])
    }
}
