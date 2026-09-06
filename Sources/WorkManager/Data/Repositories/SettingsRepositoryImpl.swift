import Foundation

/// SettingsRepositoryProtocol 구현체 (UserDefaults 기반)
public final class SettingsRepositoryImpl: SettingsRepositoryProtocol, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key = "workmanager_app_settings"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func loadSettings() -> AppSettings {
        guard let data = userDefaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }

        // 터미널 앱 전략 변경: macOS Terminal(.terminal)로 전환 마이그레이션
        let migrationKey = "workmanager_has_migrated_to_native_terminal_v2"
        if !userDefaults.bool(forKey: migrationKey) {
            userDefaults.set(true, forKey: migrationKey)
            saveSettings(settings)
        }

        return settings
    }

    public func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: key)
        }
    }
}
