/// Coordinates palm selection, complete tap recognition, and fresh click evidence.
/// Keyboard handling, device attribution, and posting mouse events stay outside this type.
public struct PalmGestureEngine: Sendable {
    public var configuration: TapConfiguration {
        didSet { reset() }
    }

    private var selector = PalmContactSelector()
    private var recognizer: TapRecognizer
    private var clickFilter: ClickEvidenceFilter
    private var rawStreamSynchronized = false
    private var lastTimestamp: Double?
    private var eligibleCount = 0
    private var ignoredCount = 0
    private var activeViolation = false
    private var completedViolationAt: Double?
    private var completedIgnoredContactAt: Double?
    private var completedAcceptedTapAt: Double?
    private static let freshnessInterval = 0.15

    public init(configuration: TapConfiguration = TapConfiguration()) {
        self.configuration = configuration
        recognizer = TapRecognizer(configuration: configuration)
        clickFilter = ClickEvidenceFilter(configuration: configuration)
    }

    public mutating func reset() {
        selector.reset()
        recognizer = TapRecognizer(configuration: configuration)
        clickFilter = ClickEvidenceFilter(configuration: configuration)
        rawStreamSynchronized = false
        lastTimestamp = nil
        eligibleCount = 0
        ignoredCount = 0
        activeViolation = false
        completedViolationAt = nil
        completedIgnoredContactAt = nil
        completedAcceptedTapAt = nil
    }

    public mutating func cancelCurrentGesture() {
        recognizer.cancelCurrentGesture()
    }

    public mutating func process(contacts: [TouchContact], timestamp: Double) -> TapDecision? {
        guard timestamp.isFinite,
            contacts.allSatisfy(\.isValid),
            Set(contacts.map(\.id)).count == contacts.count,
            lastTimestamp.map({ timestamp > $0 }) ?? true
        else {
            reset()
            return .rejected(reason: .invalidData)
        }

        if let previousTimestamp = lastTimestamp,
            eligibleCount + ignoredCount > 0,
            timestamp - previousTimestamp > Self.freshnessInterval
        {
            reset()
            lastTimestamp = timestamp
            if contacts.isEmpty {
                rawStreamSynchronized = true
                _ = recognizer.process(contacts: [], timestamp: timestamp)
                clickFilter.update(contacts: [], timestamp: timestamp)
            }
            return .rejected(reason: .interrupted)
        }

        lastTimestamp = timestamp
        if contacts.isEmpty { rawStreamSynchronized = true }

        let selection = selector.select(contacts: contacts, configuration: configuration)
        let startsNewFingerGesture = eligibleCount == 0 && !selection.eligible.isEmpty
        if startsNewFingerGesture {
            completedViolationAt = nil
            completedIgnoredContactAt = nil
            completedAcceptedTapAt = nil
        }
        if selection.invalidated {
            // Do this before processing a potentially empty eligible frame: leaving the area is
            // not a finger release and must never complete a successful tap.
            recognizer.cancelCurrentGesture()
            activeViolation = true
        }
        if selection.eligible.isEmpty && activeViolation {
            completedViolationAt = timestamp
            activeViolation = false
        }
        if contacts.isEmpty && eligibleCount == 0 && ignoredCount > 0 {
            completedIgnoredContactAt = timestamp
        }
        eligibleCount = selection.eligible.count
        ignoredCount = selection.ignored.count

        clickFilter.update(contacts: selection.eligible, timestamp: timestamp)
        let decision = recognizer.process(contacts: selection.eligible, timestamp: timestamp)
        if let decision {
            clickFilter.finish(decision: decision, timestamp: timestamp)
            if case .accepted = decision { completedAcceptedTapAt = timestamp }
        }
        return decision
    }

    /// Call only for a click independently attributed to the selected trackpad.
    public func shouldBlockClick(at timestamp: Double) -> Bool {
        guard rawStreamSynchronized, let lastTimestamp, isFresh(lastTimestamp, at: timestamp) else { return false }
        if eligibleCount > 0 {
            return activeViolation || clickFilter.shouldBlock(at: timestamp)
        }
        // Native tap clicks can arrive after the intentional fingers lift while the wrist stays.
        if let completedAcceptedTapAt, isFresh(completedAcceptedTapAt, at: timestamp) { return false }
        if ignoredCount > 0 { return true }
        return completedViolationAt.map { isFresh($0, at: timestamp) } == true
            || completedIgnoredContactAt.map { isFresh($0, at: timestamp) } == true
            || clickFilter.shouldBlock(at: timestamp)
    }

    private func isFresh(_ evidenceTimestamp: Double, at timestamp: Double) -> Bool {
        timestamp.isFinite && (0...Self.freshnessInterval).contains(timestamp - evidenceTimestamp)
    }
}
