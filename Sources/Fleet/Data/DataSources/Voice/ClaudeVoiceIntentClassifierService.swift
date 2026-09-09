import Foundation

/// 여러 스레드(정상 종료 콜백, 타임아웃 콜백)에서 동시에 발생할 수 있는 continuation resume을 한 번만 실행되도록 보장
private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false

    func resumeOnce(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else { return }
        hasResumed = true
        action()
    }
}

/// 로컬에 설치된 Claude Code CLI(-p 헤드리스 모드)를 이용해 자유 발화를 VoiceIntent로 분류하는 서비스
public final class ClaudeVoiceIntentClassifierService: VoiceIntentClassifierServiceProtocol, @unchecked Sendable {
    private let binaryName = "claude"
    private let timeoutSeconds: TimeInterval = 8

    public init() {}

    public var isAvailable: Bool {
        AIAgentDiscovery.isInstalled(binaryName: binaryName)
    }

    public func classify(text: String, repositoryNames: [String]) async -> VoiceIntent? {
        guard let path = AIAgentDiscovery.resolvedPath(binaryName: binaryName) else { return nil }
        let prompt = Self.buildPrompt(text: text, repositoryNames: repositoryNames)

        let output = await runProcess(executablePath: path, arguments: ["-p", prompt])
        guard let output = output else { return nil }
        return Self.parseIntent(from: output, fallbackRaw: text)
    }

    private func runProcess(executablePath: String, arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = FileManager.default.temporaryDirectory

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = FileHandle.nullDevice

            let resumeGuard = ResumeGuard()

            process.terminationHandler = { proc in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8)
                resumeGuard.resumeOnce { continuation.resume(returning: proc.terminationStatus == 0 ? text : nil) }
            }

            do {
                try process.run()
            } catch {
                resumeGuard.resumeOnce { continuation.resume(returning: nil) }
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) {
                if process.isRunning {
                    process.terminate()
                }
                resumeGuard.resumeOnce { continuation.resume(returning: nil) }
            }
        }
    }

    private static func buildPrompt(text: String, repositoryNames: [String]) -> String {
        let repoList = repositoryNames.isEmpty ? "(없음)" : repositoryNames.joined(separator: ", ")
        return """
        당신은 macOS 앱 "Fleet" 안에서 동작하는 음성 비서 "자비스"입니다. Fleet는 GitHub 저장소를 추적하고 메모를 남기는 앱입니다.
        도구를 사용하지 말고, 아래 발화를 보고 다른 설명 없이 JSON 한 줄만 출력하세요.

        현재 관리 중인 저장소 목록: \(repoList)
        사용자 발화: "\(text)"

        먼저 발화가 Fleet 앱 명령에 해당하는지 판단하세요. 해당하면 아래 intent 중 하나로 분류합니다:
        - briefing: 전체 저장소 방치 현황 브리핑 요청
        - open_repository: 특정 저장소를 열어달라는 요청 (name에 저장소 목록 중 정확히 일치하는 이름)
        - repository_status: 특정 저장소 또는 현재 열려있는 저장소의 상태 조회
        - memo_summary: 메모 현황/개수 조회
        - help: Fleet 사용법 안내 요청

        Fleet 명령이 아니라 인사, 잡담, 일반 지식 질문 등 자유로운 대화이면 intent를 "conversation"으로 하고,
        reply 필드에 자비스의 말투로 자연스럽고 간결한 한국어 답변을 1~3문장으로 작성하세요 (마크다운 금지, 순수 텍스트).

        출력 형식(JSON만, 다른 텍스트 금지):
        {"intent": "<intent>", "name": <저장소 이름 문자열 또는 null>, "reply": <conversation일 때만 답변 문자열, 그 외 null>}
        """
    }

    private struct ClassificationResult: Decodable {
        let intent: String
        let name: String?
        let reply: String?
    }

    private static func parseIntent(from output: String, fallbackRaw: String) -> VoiceIntent? {
        guard let start = output.firstIndex(of: "{"),
              let end = output.lastIndex(of: "}"),
              start < end else {
            return nil
        }
        let jsonSubstring = output[start...end]
        guard let data = jsonSubstring.data(using: .utf8),
              let result = try? JSONDecoder().decode(ClassificationResult.self, from: data) else {
            return nil
        }

        switch result.intent {
        case "briefing":
            return .briefing
        case "open_repository":
            guard let name = result.name, !name.isEmpty else { return .unrecognized(raw: fallbackRaw) }
            return .openRepository(name: name)
        case "repository_status":
            return .repositoryStatus(name: result.name)
        case "memo_summary":
            return .memoSummary(name: result.name)
        case "help":
            return .help
        case "conversation":
            guard let reply = result.reply, !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .unrecognized(raw: fallbackRaw)
            }
            return .conversation(reply: reply)
        default:
            return .unrecognized(raw: fallbackRaw)
        }
    }
}
