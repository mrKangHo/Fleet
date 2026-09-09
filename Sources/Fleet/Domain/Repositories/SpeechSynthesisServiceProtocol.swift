import Foundation

/// 텍스트를 음성으로 읽어주는 서비스 프로토콜 (Domain Layer 인터페이스)
public protocol SpeechSynthesisServiceProtocol: Sendable {
    /// 주어진 텍스트를 음성으로 읽습니다. voiceIdentifier가 nil이면 자동으로 최적의 한국어 보이스를 선택합니다.
    /// rate는 0.0(가장 느림)~1.0(가장 빠름) 범위이며, 발화가 끝나면(중단된 경우 포함) onFinish가 호출됩니다.
    func speak(_ text: String, voiceIdentifier: String?, rate: Float, onFinish: @escaping () -> Void)

    /// 진행 중인 발화를 중단합니다.
    func stopSpeaking()

    /// 선택 가능한 한국어 보이스 목록을 반환합니다.
    func availableVoices() -> [SpeechVoiceOption]
}
