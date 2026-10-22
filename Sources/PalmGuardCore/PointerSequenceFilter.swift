/// Balances suppressed pointer sequences without affecting another device's buttons.
public struct PointerSequenceFilter: Sendable {
    public enum Phase: Sendable { case down, drag, up }

    private struct Button: Hashable, Sendable {
        let senderID: UInt64
        let number: Int64
    }

    private var blocked: [Button: Int64] = [:]

    public init() {}

    /// Losing the event stream invalidates sequence ownership. A subsequent up
    /// may pass without its down; preserving unrelated input is safer than
    /// guessing which device still holds a button.
    public mutating func reset() { blocked.removeAll() }

    public mutating func shouldSuppress(
        phase: Phase, senderID: UInt64, button: Int64, eventNumber: Int64,
        blockNewPress: Bool = false
    ) -> Bool {
        guard senderID != 0 else { return false }
        let key = Button(senderID: senderID, number: button)
        switch phase {
        case .down:
            // A fresh down supersedes a sequence whose up was lost.
            blocked.removeValue(forKey: key)
            if blockNewPress { blocked[key] = eventNumber }
            return blockNewPress
        case .drag:
            return blocked[key] != nil
        case .up:
            // Apple documents the same event number for matching down/up.
            guard blocked[key] == eventNumber else { return false }
            blocked.removeValue(forKey: key)
            return true
        }
    }
}
