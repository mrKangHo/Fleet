import Foundation
import AVFoundation

/// AVSpeechSynthesizer 기반 한국어 음성 합성 서비스 (Enhanced/Premium 보이스 우선 선택)
public final class SpeechSynthesisService: NSObject, SpeechSynthesisServiceProtocol, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinishHandler: (() -> Void)?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ text: String, onFinish: @escaping () -> Void) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onFinish()
            return
        }
        onFinishHandler = onFinish
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.preferredKoreanVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private static func preferredKoreanVoice() -> AVSpeechSynthesisVoice? {
        let koreanVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ko-KR" }
        let enhanced = koreanVoices.first { $0.quality == .enhanced || $0.quality == .premium }
        return enhanced ?? koreanVoices.first ?? AVSpeechSynthesisVoice(language: "ko-KR")
    }
}

extension SpeechSynthesisService: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinishHandler?()
        onFinishHandler = nil
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinishHandler?()
        onFinishHandler = nil
    }
}
