import Foundation

/// 자유롭게 말한 음성 명령을 AI를 통해 VoiceIntent로 분류하는 서비스 프로토콜
public protocol VoiceIntentClassifierServiceProtocol: Sendable {
    /// 이 서비스가 현재 사용 가능한지(예: 필요한 CLI가 설치되어 있는지) 여부
    var isAvailable: Bool { get }

    /// 발화 텍스트와 현재 관리 중인 저장소 이름 목록을 참고해 의도를 분류합니다.
    /// 분류에 실패하거나 서비스를 사용할 수 없으면 nil을 반환합니다.
    func classify(text: String, repositoryNames: [String]) async -> VoiceIntent?
}
