import Foundation
import PalmGuardCore

enum NativeTapSetting: Int {
    case unknown = -1
    case disabled = 0
    case enabled = 1
}

struct AppSettings: Codable {
    var configuration = TapConfiguration()
    var nativeTapsDisabledConfirmed = false
}

enum SettingsStore {
    private static let key = "PalmGuard.settings.v1"

    static func load() -> AppSettings {
        decode(UserDefaults.standard.data(forKey: key))
    }

    static func decode(_ data: Data?) -> AppSettings {
        guard let data,
            var settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        settings.configuration = settings.configuration.sanitized
        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
