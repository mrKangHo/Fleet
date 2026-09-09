import Foundation

/// 음성 명령에서 파싱된 사용자 의도
public enum VoiceIntent: Equatable, Sendable {
    case briefing
    case openRepository(name: String)
    case repositoryStatus(name: String?)
    case memoSummary(name: String?)
    case help
    case unrecognized(raw: String)
}
