import Foundation

/// 앱 설정 접근 프로토콜 (Domain Layer 인터페이스)
public protocol SettingsRepositoryProtocol: Sendable {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
}
