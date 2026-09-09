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
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in onPartialResult(text) }

                if result.isFinal {
                    Task { @MainActor [weak self] in
                        self?.silenceTimer?.invalidate()
                        onFinalResult(text)
                    }
                    self.stopListening()
                } else {
                    self.resetSilenceTimer(finalText: text, onFinalResult: onFinalResult)
                }
            }

            if let error = error {
                Task { @MainActor in onError(error) }
                self.stopListening()
            }
        }
    }

    private func resetSilenceTimer(finalText: String, onFinalResult: @escaping (String) -> Void) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.silenceTimer?.invalidate()
            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceInterval, repeats: false) { [weak self] _ in
                onFinalResult(finalText)
                self?.stopListening()
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
