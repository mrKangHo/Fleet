import Foundation

/// 음성 명령에서 파싱된 사용자 의도
public enum VoiceIntent: Equatable, Sendable {
    case briefing
    case openRepository(name: String)
    case repositoryStatus(name: String?)
    case memoSummary(name: String?)
    case help
    /// Fleet의 정해진 명령에 해당하지 않는 일반 대화·질문. reply는 AI가 생성한 자비스의 답변.
    case conversation(reply: String)
    case unrecognized(raw: String)
}
