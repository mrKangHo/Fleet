import Foundation
import AVFoundation

/// 로컬에 설치된 MeloTTS(Python) 서버를 통해 한국어 음성을 합성하는 서비스.
/// 모델 로딩 비용을 피하기 위해 백그라운드 FastAPI 프로세스를 한 번만 띄우고 재사용한다.
public final class MeloTTSSpeechSynthesisService: NSObject, SpeechSynthesisServiceProtocol, @unchecked Sendable {
    public enum MeloTTSError: LocalizedError {
        case notInstalled
        case serverStartTimeout
        case synthesisFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "MeloTTS가 설치되어 있지 않습니다."
            case .serverStartTimeout:
                return "MeloTTS 서버가 시간 내에 준비되지 않았습니다."
            case .synthesisFailed(let message):
                return "MeloTTS 합성 실패: \(message)"
            }
        }
    }

    /// MeloTTS 설치 위치. Fleet가 직접 다운로드하지 않으며, 이 경로에 가상환경이 있어야 사용 가능하다.
    public static let installDirectory: String = (NSHomeDirectory() as NSString)
        .appendingPathComponent("Library/Application Support/Fleet/MeloTTS")

    public static var pythonPath: String {
        (installDirectory as NSString).appendingPathComponent(".venv/bin/python3")
    }

    public static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: pythonPath)
    }

    private let port: Int = 8765
    private var serverProcess: Process?
    private var audioPlayer: AVAudioPlayer?
    private var onFinishHandler: (() -> Void)?
    private let lock = NSLock()

    public override init() {
        super.init()
    }

    deinit {
        serverProcess?.terminate()
    }

    public func availableVoices() -> [SpeechVoiceOption] {
        guard Self.isInstalled else { return [] }
        return [SpeechVoiceOption(id: "melo-kr-default", name: "MeloTTS 한국어", isEnhanced: false)]
    }

    public func speak(_ text: String, voiceIdentifier: String?, rate: Float, onFinish: @escaping () -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { onFinish(); return }
        guard Self.isInstalled else { onFinish(); return }

        onFinishHandler = onFinish
        let speed = Self.mapRateToSpeed(rate)

        Task {
            do {
                try await ensureServerRunning()
                let data = try await requestSynthesis(text: trimmed, speed: speed)
                await MainActor.run { self.playAudio(data: data) }
            } catch {
                await MainActor.run { self.finish() }
            }
        }
    }

    public func stopSpeaking() {
        audioPlayer?.stop()
        finish()
    }

    // MARK: - Server Lifecycle

    private func ensureServerRunning() async throws {
        if await isHealthy() { return }

        try startServerProcessIfNeeded()

        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            if await isHealthy() { return }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw MeloTTSError.serverStartTimeout
    }

    private func startServerProcessIfNeeded() throws {
        lock.lock()
        defer { lock.unlock() }

        guard serverProcess == nil || serverProcess?.isRunning != true else { return }

        guard let resourceURL = Bundle.module.url(forResource: "melo_tts_server", withExtension: "py") else {
            throw MeloTTSError.notInstalled
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.pythonPath)
        process.arguments = [resourceURL.path, "--port", "\(port)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        serverProcess = process
    }

    private func isHealthy() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private struct SynthesizeRequestBody: Encodable {
        let text: String
        let speed: Float
    }

    private func requestSynthesis(text: String, speed: Float) async throws -> Data {
        guard let url = URL(string: "http://127.0.0.1:\(port)/synthesize") else {
            throw MeloTTSError.synthesisFailed("invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(SynthesizeRequestBody(text: text, speed: speed))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw MeloTTSError.synthesisFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        return data
    }

    // MARK: - Playback

    @MainActor
    private func playAudio(data: Data) {
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            self.audioPlayer = player
            player.play()
        } catch {
            finish()
        }
    }

    private func finish() {
        let handler = onFinishHandler
        onFinishHandler = nil
        handler?()
    }

    /// Settings의 0.3~0.65 스케일(Apple rate 기준)을 MeloTTS의 speed 배율(0.75~1.35)로 변환
    private static func mapRateToSpeed(_ rate: Float) -> Float {
        let clamped = min(max(rate, 0.3), 0.65)
        let t = (clamped - 0.3) / (0.65 - 0.3)
        return 0.75 + t * (1.35 - 0.75)
    }
}

extension MeloTTSSpeechSynthesisService: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finish() }
    }
}
