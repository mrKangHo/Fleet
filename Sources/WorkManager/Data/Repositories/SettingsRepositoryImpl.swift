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

        // 터미널 앱: 내장 터미널 추천 프로필(iTerm2 스타일)로 최신화 마이그레이션
        let migrationKey = "workmanager_has_migrated_to_iterm_profile_v2"
        if !userDefaults.bool(forKey: migrationKey) {
            userDefaults.set(true, forKey: migrationKey)
            var migrated = settings
            migrated.terminalApp = .iTerm
            saveSettings(migrated)
            return migrated
        }

        return settings
    }

    public func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: key)
        }
    }
}
