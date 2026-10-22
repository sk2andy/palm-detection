import Foundation

/// A conservative click policy for events already associated with the selected device.
/// Device attribution and balanced mouse-down/up suppression belong to the caller.
public struct ClickEvidenceFilter: Sendable {
    public var configuration: TapConfiguration {
        didSet { reset() }
    }

    private var isReady = false
    private var lastTimestamp: Double?
    private var gesture: Gesture?
    private var completed: CompletedEvidence?
    private static let freshnessInterval = 0.15

    private struct Gesture: Sendable {
        var isRejected = false
    }

    private struct CompletedEvidence: Sendable {
        let timestamp: Double
        var shouldBlock: Bool
    }

    public init(configuration: TapConfiguration = TapConfiguration()) {
        self.configuration = configuration
    }

    public mutating func reset() {
        isReady = false
        lastTimestamp = nil
        gesture = nil
        completed = nil
    }

    public mutating func update(contacts: [TouchContact], timestamp: Double) {
        let previousTimestamp = lastTimestamp
        guard timestamp.isFinite,
            contacts.allSatisfy(\.isValid),
            Set(contacts.map(\.id)).count == contacts.count,
            previousTimestamp.map({ timestamp > $0 }) ?? true
        else {
            reset()
            return
        }
        lastTimestamp = timestamp

        if gesture != nil, let previousTimestamp, timestamp - previousTimestamp > Self.freshnessInterval {
            // A resumed stream is not proof that these contacts belong to the old gesture.
            reset()
            lastTimestamp = timestamp
            isReady = contacts.isEmpty
            return
        }

        if contacts.isEmpty {
            if let gesture {
                completed = CompletedEvidence(
                    timestamp: timestamp,
                    shouldBlock: gesture.isRejected
                )
            }
            gesture = nil
            isReady = true
            return
        }

        completed = nil
        guard isReady else { return }

        var current = gesture ?? Gesture()
        let configuration = configuration.sanitized
        if contacts.count > 2 {
            current.isRejected = true
        }

        // Moving the pointer or resting a finger before pressing is normal physical-click
        // behavior. Temporal and movement restrictions apply only to completed tap candidates.
        for contact in contacts {
            if !configuration.area.contains(contact.position) || contact.size > configuration.maximumSize {
                current.isRejected = true
            }
        }
        gesture = current
    }

    /// Add the final temporal verdict after `update` receives the corresponding empty frame.
    public mutating func finish(decision: TapDecision, timestamp: Double) {
        guard isReady, gesture == nil, completed?.timestamp == timestamp else { return }
        switch decision {
        case .accepted:
            completed?.shouldBlock = false
        case .rejected(let reason):
            switch reason {
            case .invalidData, .notReady, .interrupted:
                completed = nil
            case .cancelled:
                // Cancellation often means a physical click already passed through.
                break
            default:
                completed?.shouldBlock = true
            }
        }
    }

    public func shouldBlock(at timestamp: Double) -> Bool {
        guard isReady, timestamp.isFinite else { return false }
        if let gesture, let lastTimestamp {
            let age = timestamp - lastTimestamp
            guard (0...Self.freshnessInterval).contains(age) else { return false }
            return gesture.isRejected
        }
        if let completed {
            let age = timestamp - completed.timestamp
            return (0...Self.freshnessInterval).contains(age) && completed.shouldBlock
        }
        return false
    }
}
