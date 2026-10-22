/// Recognizes deliberate taps without suppressing any native mouse or keyboard event.
/// Native gestures are excluded using the complete raw contact frame before area selection.
public struct PalmGestureEngine: Sendable {
    public var configuration: TapConfiguration {
        didSet { reset() }
    }

    private var selector = PalmContactSelector()
    private var recognizer: TapRecognizer
    private var lastTimestamp: Double?
    private var rawContactCount = 0
    private var requiresFingerRelease = true
    private var sawUnsynchronizedContact = false
    private var nativeGestureContactIDs: Set<Int> = []
    private static let maximumFrameGap = 0.15

    public init(configuration: TapConfiguration = TapConfiguration()) {
        self.configuration = configuration
        recognizer = TapRecognizer(configuration: configuration)
    }

    /// Require a finger-free frame after startup, settings changes, or a broken input stream.
    /// A broad resting palm may stay on the surface while the recognizer re-arms.
    public mutating func reset() {
        selector.reset()
        recognizer = TapRecognizer(configuration: configuration)
        lastTimestamp = nil
        rawContactCount = 0
        requiresFingerRelease = true
        sawUnsynchronizedContact = false
        nativeGestureContactIDs.removeAll()
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

        let fingerIDs = Set(contacts.filter { $0.size <= configuration.sanitized.maximumSize }.map(\.id))
        if let previousTimestamp = lastTimestamp,
            rawContactCount > 0,
            timestamp - previousTimestamp > Self.maximumFrameGap
        {
            reset()
            lastTimestamp = timestamp
            rawContactCount = contacts.count
            if fingerIDs.isEmpty { arm(with: contacts, at: timestamp) }
            return .rejected(reason: .interrupted)
        }
        lastTimestamp = timestamp
        rawContactCount = contacts.count

        if requiresFingerRelease {
            guard fingerIDs.isEmpty else {
                sawUnsynchronizedContact = true
                return nil
            }
            let needsStartupRejection = sawUnsynchronizedContact
            arm(with: contacts, at: timestamp)
            return needsStartupRejection ? .rejected(reason: .notReady) : nil
        }

        if !nativeGestureContactIDs.isEmpty {
            nativeGestureContactIDs.formIntersection(contacts.map(\.id))
            nativeGestureContactIDs.formUnion(fingerIDs)
            if nativeGestureContactIDs.isEmpty { arm(with: contacts, at: timestamp) }
            return nil
        }

        // Count fingers across the entire surface: an outside finger still belongs to a
        // native three-finger drag. Broad palms do not turn a deliberate two-finger tap into three.
        if fingerIDs.count >= 3 {
            nativeGestureContactIDs = fingerIDs
            selector.reset()
            recognizer.reset()
            return .rejected(reason: .tooManyFingers)
        }

        let selection = selector.select(contacts: contacts, configuration: configuration)
        if selection.invalidated {
            // Leaving the permitted area is not a release and must never finish an accepted tap.
            recognizer.cancelCurrentGesture()
        }
        return recognizer.process(contacts: selection.eligible, timestamp: timestamp)
    }

    private mutating func arm(with contacts: [TouchContact], at timestamp: Double) {
        requiresFingerRelease = false
        sawUnsynchronizedContact = false
        selector.reset()
        // Remember broad contacts already resting here so later shrinking cannot turn them into taps.
        _ = selector.select(contacts: contacts, configuration: configuration)
        recognizer.reset()
        _ = recognizer.process(contacts: [], timestamp: timestamp)
    }
}
