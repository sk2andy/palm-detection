import Foundation

enum ActivationProblem: String, Identifiable {
    case trackpadDisconnected
    case accessibilityRequired
    case nativeTapsEnabled
    case nativeTapStateUnknown
    case eventAccessRequired

    var id: String { rawValue }

    var status: String {
        switch self {
        case .trackpadDisconnected: "Externes Trackpad verbinden und neu verbinden."
        case .accessibilityRequired: "Bedienungshilfen für PalmGuard freigeben."
        case .nativeTapsEnabled: "Zuerst natives Tippen zum Klicken in macOS ausschalten."
        case .nativeTapStateUnknown: "Trackpad-Einstellung prüfen und unten bestätigen."
        case .eventAccessRequired: "Mausbeobachtung fehlt. Bedienungshilfen / Eingabeüberwachung prüfen."
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
            "macOS konnte die Mausbeobachtung nicht öffnen. Prüfe PalmGuard unter Bedienungshilfen "
                + "und Eingabeüberwachung. Starte PalmGuard nach der Freigabe neu.\n\nAktuelle App:\n\(appPath)"
        case .trackpadDisconnected:
            "Verbinde ein externes Apple Trackpad. Klicke danach auf „Neu verbinden“ und aktiviere den Schutz erneut."
        case .nativeTapsEnabled:
            "Schalte in den macOS-Trackpad-Einstellungen „Tippen zum Klicken“ aus. "
                + "PalmGuard übernimmt dann Ein- und Zweifinger-Taps innerhalb deiner Fläche. "
                + "Druck-Klicks und Drei-Finger-Drags übernimmt weiterhin macOS."
        case .nativeTapStateUnknown:
            "PalmGuard kann die aktuelle Tap-Einstellung dieses Trackpads nicht auslesen. "
                + "Prüfe, dass „Tippen zum Klicken“ in macOS ausgeschaltet ist, und bestätige das in PalmGuard. "
                + "Sonst können doppelte oder ungefilterte Tap-Klicks entstehen."
        }
    }

    var recoveryTitle: String {
        switch self {
        case .accessibilityRequired: "Bedienungshilfen öffnen"
        case .eventAccessRequired: "Eingabeüberwachung öffnen"
        case .nativeTapsEnabled, .nativeTapStateUnknown: "Trackpad-Einstellungen öffnen"
        case .trackpadDisconnected: "Neu verbinden"
        }
    }
}

struct ActivationReadiness {
    var trackpadConnected: Bool
    var accessibilityGranted: Bool
    var nativeTapSetting: NativeTapSetting
    var nativeTapsDisabledConfirmed: Bool

    var problem: ActivationProblem? {
        guard trackpadConnected else { return .trackpadDisconnected }
        guard accessibilityGranted else { return .accessibilityRequired }
        switch nativeTapSetting {
        case .enabled: return .nativeTapsEnabled
        case .unknown where !nativeTapsDisabledConfirmed: return .nativeTapStateUnknown
        default: return nil
        }
    }
}
