import Foundation

/// 음성을 텍스트로 변환하는 서비스 프로토콜 (Domain Layer 인터페이스)
public protocol SpeechRecognitionServiceProtocol: Sendable {
    /// 마이크 및 음성 인식 권한을 요청하고 허용 여부를 반환합니다.
    func requestAuthorization() async -> Bool

    /// 듣기를 시작합니다. 부분/최종 인식 결과와 에러를 콜백으로 전달합니다.
    func startListening(
        onPartialResult: @escaping (String) -> Void,
        onFinalResult: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    )

    /// 듣기를 중단합니다.
    func stopListening()
}
