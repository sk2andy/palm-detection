public struct ContactSelection: Equatable, Sendable {
    public let eligible: [TouchContact]
    public let ignored: [TouchContact]
    public let invalidated: Bool
}

/// Keeps resting palms independent of intentional fingers without turning boundary entry into a tap.
public struct PalmContactSelector: Sendable {
    private var ignoredIDs: Set<Int> = []
    private var eligibleIDs: Set<Int> = []

    public init() {}

    public mutating func reset() {
        ignoredIDs.removeAll()
        eligibleIDs.removeAll()
    }

    public mutating func select(contacts: [TouchContact], configuration: TapConfiguration) -> ContactSelection {
        let ids = Set(contacts.map(\.id))
        ignoredIDs.formIntersection(ids)
        eligibleIDs.formIntersection(ids)

        guard ids.count == contacts.count else {
            ignoredIDs.formUnion(ids)
            eligibleIDs.removeAll()
            return ContactSelection(eligible: [], ignored: contacts, invalidated: true)
        }

        let configuration = configuration.sanitized
        var eligible: [TouchContact] = []
        var ignored: [TouchContact] = []
        var invalidated = false

        for contact in contacts {
            let isEligible =
                contact.isValid
                && configuration.area.contains(contact.position)
                && contact.size <= configuration.maximumSize
            if !isEligible {
                if eligibleIDs.contains(contact.id) || !contact.isValid { invalidated = true }
                ignoredIDs.insert(contact.id)
                eligibleIDs.remove(contact.id)
            }
            if ignoredIDs.contains(contact.id) {
                ignored.append(contact)
            } else {
                eligibleIDs.insert(contact.id)
                eligible.append(contact)
            }
        }
        return ContactSelection(eligible: eligible, ignored: ignored, invalidated: invalidated)
    }
}
