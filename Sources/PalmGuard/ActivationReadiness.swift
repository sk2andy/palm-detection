import Foundation

enum ActivationProblem: String, Identifiable {
    case trackpadDisconnected
    case accessibilityRequired
    case identityUnavailable
    case nativeTapsEnabled
    case eventAccessRequired

    var id: String { rawValue }

    var status: String {
        switch self {
        case .trackpadDisconnected: "Externes Trackpad verbinden und neu verbinden."
        case .accessibilityRequired: "Bedienungshilfen für PalmGuard freigeben."
        case .identityUnavailable: "Klickquelle auf diesem macOS nicht verfügbar. Eigene Taps verwenden."
        case .nativeTapsEnabled: "Zuerst natives Tippen zum Klicken ausschalten und unten bestätigen."
        case .eventAccessRequired: "Ereigniszugriff fehlt. Bedienungshilfen / Eingabeüberwachung prüfen."
        }
    }

    func explanation(appPath: String) -> String {
        switch self {
        case .accessibilityRequired:
            "macOS erlaubt dieser App noch keinen Zugriff auf Bedienungshilfen. "
                + "Wenn PalmGuard dort bereits eingeschaltet ist, kann die Freigabe zu einem älteren Build gehören. "
                + "Entferne dann den PalmGuard-Eintrag mit − und füge die aktuelle App mit + erneut hinzu.\n\n"
                + "Aktuelle App:\n\(appPath)\n\nDanach PalmGuard neu starten."
        case .eventAccessRequired:
            "macOS konnte den Mausereignisfilter nicht öffnen. Prüfe PalmGuard unter Bedienungshilfen "
                + "und Eingabeüberwachung. Starte PalmGuard nach der Freigabe neu.\n\nAktuelle App:\n\(appPath)"
        case .trackpadDisconnected:
            "Verbinde ein externes Apple Trackpad. Klicke danach auf „Neu verbinden“ und aktiviere den Schutz erneut."
        case .identityUnavailable:
            "Die Herkunft der Klicks lässt sich auf diesem macOS nicht sicher bestimmen. "
                + "Wähle „Eigene Taps erzeugen“ und folge den dortigen Einrichtungsschritten."
        case .nativeTapsEnabled:
            "Schalte in den macOS-Trackpad-Einstellungen „Tippen zum Klicken“ aus. "
                + "Bestätige das anschließend in PalmGuard, damit keine doppelten Klicks entstehen."
        }
    }

    var recoveryTitle: String {
        switch self {
        case .accessibilityRequired: "Bedienungshilfen öffnen"
        case .eventAccessRequired: "Eingabeüberwachung öffnen"
        case .nativeTapsEnabled: "Trackpad-Einstellungen öffnen"
        case .trackpadDisconnected: "Neu verbinden"
        case .identityUnavailable: "Verstanden"
        }
    }
}

struct ActivationReadiness {
    var trackpadConnected: Bool
    var accessibilityGranted: Bool
    var identityAvailable: Bool
    var mode: ProtectionMode
    var nativeTapsDisabledConfirmed: Bool
    var nativeTapPreferenceEnabled: Bool

    var problem: ActivationProblem? {
        guard trackpadConnected else { return .trackpadDisconnected }
        guard accessibilityGranted else { return .accessibilityRequired }
        if mode == .filterClicks && !identityAvailable { return .identityUnavailable }
        if mode == .deliberateTaps && (!nativeTapsDisabledConfirmed || nativeTapPreferenceEnabled) {
            return .nativeTapsEnabled
        }
        return nil
    }
}
