import Foundation

/// 앱 표시 언어 선택 (시스템 언어와 무관하게 앱 내에서 강제 지정 가능)
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case ko
    case en
    case ja
    case zhHans = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "시스템 언어 (System)"
        case .ko: return "한국어"
        case .en: return "English"
        case .ja: return "日本語"
        case .zhHans: return "中文(简体)"
        }
    }

    /// nil인 경우 시스템 언어를 그대로 따라가도록(autoupdatingCurrent) 처리
    public var locale: Locale {
        switch self {
        case .system: return Locale.autoupdatingCurrent
        case .ko: return Locale(identifier: "ko")
        case .en: return Locale(identifier: "en")
        case .ja: return Locale(identifier: "ja")
        case .zhHans: return Locale(identifier: "zh-Hans")
        }
    }
}
