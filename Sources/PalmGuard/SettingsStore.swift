import Foundation
import PalmGuardCore

enum ProtectionMode: String, Codable, CaseIterable, Identifiable {
    case filterClicks
    case deliberateTaps

    var id: String { rawValue }
    var title: String {
        switch self {
        case .filterClicks: "Vorhandene Klicks filtern"
        case .deliberateTaps: "Eigene Taps erzeugen"
        }
    }
}

struct AppSettings: Codable {
    var configuration = TapConfiguration()
    var mode = ProtectionMode.filterClicks
    var nativeTapsDisabledConfirmed = false
}

enum SettingsStore {
    private static let key = "PalmGuard.settings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
            var settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        settings.configuration = settings.configuration.sanitized
        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// A preference is a diagnostic hint, not proof of the effective driver setting.
    static var nativeTapPreferenceEnabled: Bool {
        ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"]
            .contains { domain in
                CFPreferencesCopyAppValue("Clicking" as CFString, domain as CFString)
                    .map { ($0 as? NSNumber)?.boolValue == true } ?? false
            }
    }
}
