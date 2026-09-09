import Foundation
import AVFoundation
import Speech

public enum SpeechRecognitionError: LocalizedError, Sendable {
    case authorizationDenied
    case recognizerUnavailable
    case audioEngineFailure(String)

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "마이크 또는 음성 인식 권한이 거부되었습니다. 시스템 설정에서 권한을 허용해 주세요."
        case .recognizerUnavailable:
            return "현재 음성 인식을 사용할 수 없습니다."
        case .audioEngineFailure(let message):
            return "마이크 입력 처리 중 오류가 발생했습니다: \(message)"
        }
    }
}

/// SFSpeechRecognizer + AVAudioEngine 기반 한국어 음성 인식 서비스 (가능하면 온디바이스로 처리)
public final class SpeechRecognitionService: SpeechRecognitionServiceProtocol, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private let silenceInterval: TimeInterval = 1.2
    /// 이번 듣기 세션에서 이미 최종 결과(또는 에러)를 전달했는지 여부.
    /// SFSpeechRecognizer는 정상 종료 시에도 결과와 함께(또는 직후에) 에러를 함께 전달할 수 있어,
    /// 이미 유효한 결과를 전달한 뒤에는 뒤이은 에러 콜백을 무시해야 한다.
    private var hasFinishedCurrentSession = false
    /// 이번 세션에서 유의미한 부분 인식 결과를 한 번이라도 받았는지 여부 (아래 참고)
    private var hasReceivedAnyPartialResult = false

    public init() {
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    }

    public func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func startListening(
        onPartialResult: @escaping (String) -> Void,
        onFinalResult: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        stopListening()
        hasFinishedCurrentSession = false
        hasReceivedAnyPartialResult = false

        guard let recognizer = recognizer, recognizer.isAvailable else {
            onError(SpeechRecognitionError.recognizerUnavailable)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            onError(SpeechRecognitionError.audioEngineFailure(error.localizedDescription))
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self, !self.hasFinishedCurrentSession else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in onPartialResult(text) }

                if result.isFinal {
                    self.hasFinishedCurrentSession = true
                    Task { @MainActor [weak self] in
                        self?.silenceTimer?.invalidate()
                        onFinalResult(text)
                    }
                    self.stopListening()
                    return
                } else {
                    self.resetSilenceTimer(finalText: text, onFinalResult: onFinalResult)
                }
            }

            // 이미 유효한 텍스트를 한 번이라도 받았다면, 뒤이어 오는 종료성 에러는 정상 종료 신호로
            // 간주하고 무시한다 (예: "안녕" 같은 짧은 발화에서 최종 결과와 함께 세션 종료 에러가 옴).
            if let error = error, !self.hasReceivedAnyPartialResult {
                self.hasFinishedCurrentSession = true
                Task { @MainActor in onError(error) }
                self.stopListening()
            }
        }
    }

    private func resetSilenceTimer(finalText: String, onFinalResult: @escaping (String) -> Void) {
        hasReceivedAnyPartialResult = true
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.silenceTimer?.invalidate()
            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceInterval, repeats: false) { [weak self] _ in
                guard let self = self, !self.hasFinishedCurrentSession else { return }
                self.hasFinishedCurrentSession = true
                onFinalResult(finalText)
                self.stopListening()
            }
        }
    }

    public func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
