import Testing

@testable import PalmGuardCore

@Suite("Fresh device-associated click evidence")
struct ClickEvidenceFilterTests {
    private let inside = TouchContact(id: 1, position: TouchPoint(x: 0.5, y: 0.5), size: 1)
    private let outside = TouchContact(id: 1, position: TouchPoint(x: 0.05, y: 0.5), size: 1)

    private func readyFilter() -> ClickEvidenceFilter {
        var filter = ClickEvidenceFilter()
        filter.update(contacts: [], timestamp: 0)
        return filter
    }

    @Test func noEvidenceFailsOpen() {
        #expect(!ClickEvidenceFilter().shouldBlock(at: 0))
        #expect(!readyFilter().shouldBlock(at: 0.1))
    }

    @Test func startupContactIsNotEnoughEvidence() {
        var filter = ClickEvidenceFilter()
        filter.update(contacts: [outside], timestamp: 0.01)
        #expect(!filter.shouldBlock(at: 0.02))
        filter.update(contacts: [], timestamp: 0.03)
        filter.update(contacts: [outside], timestamp: 0.04)
        #expect(filter.shouldBlock(at: 0.05))
    }

    @Test func validEarlyPressureClickPasses() {
        var filter = readyFilter()
        filter.update(contacts: [inside], timestamp: 0.01)
        #expect(!filter.shouldBlock(at: 0.02))
    }

    @Test func outsideAreaBlocksOnlyWithFreshEvidence() {
        var filter = readyFilter()
        filter.update(contacts: [outside], timestamp: 0.01)
        #expect(filter.shouldBlock(at: 0.02))
        #expect(!filter.shouldBlock(at: 0.17))
        #expect(!filter.shouldBlock(at: 0.005))
        #expect(!filter.shouldBlock(at: .nan))
    }

    @Test func violationSticksUntilAllContactsLift() {
        var filter = readyFilter()
        filter.update(contacts: [outside], timestamp: 0.01)
        filter.update(contacts: [inside], timestamp: 0.03)
        #expect(filter.shouldBlock(at: 0.04))
        filter.update(contacts: [], timestamp: 0.05)
        filter.update(contacts: [inside], timestamp: 0.07)
        #expect(!filter.shouldBlock(at: 0.08))
    }

    @Test func completedRejectionSurvivesReleaseBriefly() {
        var filter = readyFilter()
        filter.update(contacts: [outside], timestamp: 0.01)
        filter.update(contacts: [], timestamp: 0.05)
        filter.finish(decision: .rejected(reason: .outsideArea), timestamp: 0.05)
        #expect(filter.shouldBlock(at: 0.06))
        filter.update(contacts: [], timestamp: 0.10)
        #expect(filter.shouldBlock(at: 0.15))
        #expect(!filter.shouldBlock(at: 0.21))
    }

    @Test func acceptedGestureDoesNotBlockAfterRelease() {
        var filter = readyFilter()
        filter.update(contacts: [inside], timestamp: 0.01)
        filter.update(contacts: [], timestamp: 0.05)
        filter.finish(decision: .accepted(fingers: 1), timestamp: 0.05)
        #expect(!filter.shouldBlock(at: 0.06))
    }

    @Test func completedTemporalRejectionBlocks() {
        var filter = readyFilter()
        filter.update(contacts: [inside], timestamp: 0.01)
        filter.update(contacts: [], timestamp: 0.02)
        filter.finish(decision: .rejected(reason: .tooShort), timestamp: 0.02)
        #expect(filter.shouldBlock(at: 0.03))
    }

    @Test func invalidDataClearsEvidenceAndRequiresResync() {
        var filter = readyFilter()
        filter.update(contacts: [outside], timestamp: 0.01)
        filter.update(contacts: [TouchContact(id: 1, position: TouchPoint(x: .nan, y: 0.5), size: 1)], timestamp: 0.02)
        #expect(!filter.shouldBlock(at: 0.03))
        filter.update(contacts: [outside], timestamp: 0.04)
        #expect(!filter.shouldBlock(at: 0.05))
    }

    @Test func duplicateIDsAndInvalidTimesFailOpen() {
        var filter = readyFilter()
        filter.update(contacts: [outside, outside], timestamp: 0.01)
        #expect(!filter.shouldBlock(at: 0.02))
        filter.update(contacts: [], timestamp: 0.03)
        filter.update(contacts: [outside], timestamp: 0.04)
        filter.update(contacts: [outside], timestamp: 0.04)
        #expect(!filter.shouldBlock(at: 0.05))
    }

    @Test func invalidCompletedVerdictFailsOpen() {
        var filter = readyFilter()
        filter.update(contacts: [outside], timestamp: 0.01)
        filter.update(contacts: [], timestamp: 0.05)
        filter.finish(decision: .rejected(reason: .invalidData), timestamp: 0.05)
        #expect(!filter.shouldBlock(at: 0.06))
    }

    @Test func physicalCancellationDoesNotInventRejection() {
        var filter = readyFilter()
        filter.update(contacts: [inside], timestamp: 0.01)
        filter.update(contacts: [], timestamp: 0.05)
        filter.finish(decision: .rejected(reason: .cancelled), timestamp: 0.05)
        #expect(!filter.shouldBlock(at: 0.06))
    }

    @Test func longStationaryContactAllowsPressureClickButRejectedTapBlocksAfterRelease() {
        var filter = readyFilter()
        for timestamp in [0.01, 0.10, 0.20, 0.24] {
            filter.update(contacts: [inside], timestamp: timestamp)
        }
        #expect(!filter.shouldBlock(at: 0.25))
        filter.update(contacts: [], timestamp: 0.27)
        filter.finish(decision: .rejected(reason: .tooLong), timestamp: 0.27)
        #expect(filter.shouldBlock(at: 0.28))
    }

    @Test func tooManyFingersBlock() {
        var filter = readyFilter()
        filter.update(
            contacts: [
                inside,
                TouchContact(id: 2, position: inside.position, size: 1),
                TouchContact(id: 3, position: inside.position, size: 1),
            ], timestamp: 0.01)
        #expect(filter.shouldBlock(at: 0.02))
    }

    @Test func largeContactBlocks() {
        var filter = readyFilter()
        filter.update(contacts: [TouchContact(id: 1, position: inside.position, size: 3)], timestamp: 0.01)
        #expect(filter.shouldBlock(at: 0.02))
    }

    @Test func movementAllowsPressureClickButRejectedTapBlocksAfterRelease() {
        var filter = readyFilter()
        filter.update(contacts: [inside], timestamp: 0.01)
        filter.update(contacts: [TouchContact(id: 1, position: TouchPoint(x: 0.6, y: 0.5), size: 1)], timestamp: 0.03)
        #expect(!filter.shouldBlock(at: 0.04))
        filter.update(contacts: [], timestamp: 0.06)
        filter.finish(decision: .rejected(reason: .tooMuchMovement), timestamp: 0.06)
        #expect(filter.shouldBlock(at: 0.07))
    }

    @Test func streamGapRequiresResynchronization() {
        var filter = readyFilter()
        filter.update(contacts: [outside], timestamp: 0.01)
        filter.update(contacts: [outside], timestamp: 0.20)
        #expect(!filter.shouldBlock(at: 0.21))
        filter.update(contacts: [], timestamp: 0.22)
        filter.update(contacts: [outside], timestamp: 0.23)
        #expect(filter.shouldBlock(at: 0.24))
    }

    @Test func staleReleaseDoesNotRefreshRejection() {
        var filter = readyFilter()
        filter.update(contacts: [outside], timestamp: 0.01)
        filter.update(contacts: [], timestamp: 0.20)
        filter.finish(decision: .rejected(reason: .outsideArea), timestamp: 0.20)
        #expect(!filter.shouldBlock(at: 0.21))
    }

    @Test func configurationChangeDropsOldEvidence() {
        var filter = readyFilter()
        filter.update(contacts: [outside], timestamp: 0.01)
        filter.configuration.maximumSize = 2
        #expect(!filter.shouldBlock(at: 0.02))
    }
}
