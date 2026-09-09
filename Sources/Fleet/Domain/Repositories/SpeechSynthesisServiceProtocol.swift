import Foundation

/// 텍스트를 음성으로 읽어주는 서비스 프로토콜 (Domain Layer 인터페이스)
public protocol SpeechSynthesisServiceProtocol: Sendable {
    /// 주어진 텍스트를 음성으로 읽습니다. 발화가 끝나면(중단된 경우 포함) onFinish가 호출됩니다.
    func speak(_ text: String, onFinish: @escaping () -> Void)

    /// 진행 중인 발화를 중단합니다.
    func stopSpeaking()
}
