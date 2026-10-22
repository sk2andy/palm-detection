import Foundation

public enum TapRejection: String, CaseIterable, Sendable {
    case outsideArea
    case contactTooLarge
    case tooMuchMovement
    case tooLong
    case tooShort
    case tooManyFingers
    case fingersTooFarApartInTime
    case fingerReplacement
    case interrupted
    case invalidData
    case cancelled
    case notReady
}

public enum TapDecision: Equatable, Sendable {
    case accepted(fingers: Int)
    case rejected(reason: TapRejection)
}

/// Recognizes complete touch sequences; it never posts or suppresses system events.
/// Supply monotonic timestamps in seconds and only contacts currently touching the surface.
public struct TapRecognizer: Sendable {
    public var configuration: TapConfiguration {
        didSet { reset() }
    }

    private var isReady = false
    private var lastTimestamp: Double?
    private var gesture: Gesture?

    // A dropped input stream must not turn a partial gesture into a fresh tap.
    private static let maximumFrameGap = 0.12

    private struct Gesture: Sendable {
        let startedAt: Double
        var initialPositions: [Int: TouchPoint] = [:]
        var activeIDs: Set<Int> = []
        var rejection: TapRejection?

        mutating func reject(_ reason: TapRejection) {
            if rejection == nil { rejection = reason }
        }
    }

    public init(configuration: TapConfiguration = TapConfiguration()) {
        self.configuration = configuration
    }

    /// Re-arm only after the next empty frame, including after device reconnects.
    public mutating func reset() {
        isReady = false
        lastTimestamp = nil
        gesture = nil
    }

    /// A physical click or another gesture can invalidate the current tap candidate.
    public mutating func cancelCurrentGesture() {
        if gesture != nil { gesture?.reject(.cancelled) }
        isReady = false
    }

    public mutating func process(contacts: [TouchContact], timestamp: Double) -> TapDecision? {
        guard timestamp.isFinite else {
            gesture?.reject(.invalidData)
            isReady = false
            return nil
        }

        let previousTimestamp = lastTimestamp
        lastTimestamp = timestamp

        if contacts.isEmpty {
            defer {
                gesture = nil
                isReady = true
            }
            guard var completed = gesture else { return nil }
            checkTiming(&completed, timestamp: timestamp, previousTimestamp: previousTimestamp)
            let configuration = configuration.sanitized
            let duration = timestamp - completed.startedAt
            if duration < configuration.minimumDuration { completed.reject(.tooShort) }
            if let rejection = completed.rejection { return .rejected(reason: rejection) }
            return .accepted(fingers: completed.initialPositions.count)
        }

        if gesture == nil {
            gesture = Gesture(startedAt: timestamp, rejection: isReady ? nil : .notReady)
        }
        guard var current = gesture else { return nil }
        checkTiming(&current, timestamp: timestamp, previousTimestamp: previousTimestamp)
        inspect(contacts, gesture: &current, timestamp: timestamp)
        gesture = current
        return nil
    }

    private func checkTiming(_ gesture: inout Gesture, timestamp: Double, previousTimestamp: Double?) {
        if let previousTimestamp {
            if timestamp <= previousTimestamp {
                gesture.reject(.invalidData)
            } else if !gesture.initialPositions.isEmpty && timestamp - previousTimestamp > Self.maximumFrameGap {
                gesture.reject(.interrupted)
            }
        }
        if timestamp - gesture.startedAt > configuration.sanitized.maximumDuration {
            gesture.reject(.tooLong)
        }
    }

    private func inspect(_ contacts: [TouchContact], gesture: inout Gesture, timestamp: Double) {
        let configuration = configuration.sanitized
        let ids = Set(contacts.map(\.id))
        if ids.count != contacts.count || !contacts.allSatisfy(\.isValid) {
            gesture.reject(.invalidData)
            return
        }
        if contacts.count > 2 { gesture.reject(.tooManyFingers) }

        let newIDs = ids.subtracting(gesture.initialPositions.keys)
        let hasStarted = !gesture.initialPositions.isEmpty
        if hasStarted && !newIDs.isEmpty {
            if gesture.initialPositions.count + newIDs.count > 2 {
                gesture.reject(.tooManyFingers)
            }
            if !gesture.activeIDs.isSubset(of: ids) || gesture.activeIDs.count != gesture.initialPositions.count {
                gesture.reject(.fingerReplacement)
            }
            if timestamp - gesture.startedAt > configuration.maximumFingerLandingInterval {
                gesture.reject(.fingersTooFarApartInTime)
            }
        }
        // An identifier that already lifted cannot re-enter the same sequence.
        let returningIDs = ids.intersection(gesture.initialPositions.keys).subtracting(gesture.activeIDs)
        if !returningIDs.isEmpty { gesture.reject(.fingerReplacement) }

        for contact in contacts {
            if !configuration.area.contains(contact.position) { gesture.reject(.outsideArea) }
            if contact.size > configuration.maximumSize { gesture.reject(.contactTooLarge) }
            if let initialPosition = gesture.initialPositions[contact.id] {
                if initialPosition.distance(to: contact.position) > configuration.maximumMovement {
                    gesture.reject(.tooMuchMovement)
                }
            } else {
                gesture.initialPositions[contact.id] = contact.position
            }
        }
        gesture.activeIDs = ids
    }
}
