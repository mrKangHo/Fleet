import Foundation

/// 앱 사용자 환경설정 엔티티
public struct AppSettings: Codable, Hashable, Sendable {
    public var githubToken: String
    public var staleThresholdDays: Int
    public var warningThresholdDays: Int
    public var isDockBadgeEnabled: Bool
    public var isNotificationEnabled: Bool
    public var excludeArchived: Bool
    public var excludeForks: Bool
    public var autoRefreshIntervalMinutes: Int

    // MARK: - AI Agent Execution Settings
    public enum AIAgentPreset: String, Codable, CaseIterable, Sendable, Identifiable {
        case claude = "Claude Code (claude)"
        case antigravity = "Google Antigravity (agy)"
        case codex = "OpenAI Codex CLI (codex)"
        case cursor = "Cursor CLI (cursor)"
        case aider = "Aider (aider)"
        case goose = "Goose CLI (goose)"
        case openhands = "OpenHands CLI (openhands)"
        case custom = "커스텀 CLI"

        public var id: String { rawValue }

        public var shortName: String {
            switch self {
            case .claude: return "Claude"
            case .antigravity: return "Antigravity"
            case .codex: return "Codex"
            case .cursor: return "Cursor"
            case .aider: return "Aider"
            case .goose: return "Goose"
            case .openhands: return "OpenHands"
            case .custom: return "CLI"
            }
        }

        public var iconName: String {
            switch self {
            case .claude: return "brain.head.profile"
            case .antigravity: return "atom"
            case .codex: return "chevron.left.forwardslash.chevron.right"
            case .cursor: return "cursorarrow.rays"
            case .aider: return "hammer.fill"
            case .goose: return "paperplane.fill"
            case .openhands: return "hand.raised.fill"
            case .custom: return "terminal.fill"
            }
        }

        public func commandTemplate(dangerouslySkipPermissions: Bool = true) -> String {
            let skip = dangerouslySkipPermissions ? "--dangerously-skip-permissions " : ""
            switch self {
            case .claude:
                return "claude \(skip)\"{prompt}\""
            case .antigravity:
                return "agy \(skip)-i \"{prompt}\""
            case .codex:
                return "codex \(skip)\"{prompt}\""
            case .cursor:
                return "cursor \(skip)\"{prompt}\""
            case .aider:
                let aiderSkip = dangerouslySkipPermissions ? "--yes " : ""
                return "aider \(aiderSkip)--message \"{prompt}\""
            case .goose:
                return "goose run --text \"{prompt}\""
            case .openhands:
                return "openhands \(skip)\"{prompt}\""
            case .custom:
                return "echo \"{prompt}\""
            }
        }

        public var defaultCommandTemplate: String {
            commandTemplate(dangerouslySkipPermissions: true)
        }

        /// 각 AI 에이전트 도구의 CLI 실행 파일명
        public var executableName: String? {
            switch self {
            case .claude: return "claude"
            case .antigravity: return "agy"
            case .codex: return "codex"
            case .cursor: return "cursor"
            case .aider: return "aider"
            case .goose: return "goose"
            case .openhands: return "openhands"
            case .custom: return nil
            }
        }

        /// 현재 시스템(Mac)에 해당 AI CLI 도구가 실제로 설치되어 있는지 여부
        public var isInstalled: Bool {
            guard let exe = executableName else {
                return false
            }
            return AIAgentDiscovery.isInstalled(binaryName: exe)
        }

        /// 현재 Mac에 실제로 설치되어 있는 AI Agent 목록만 필터링하여 반환
        public static var installedCases: [AIAgentPreset] {
            let installed = allCases.filter { $0.isInstalled }
            return installed.isEmpty ? [.claude, .antigravity] : installed
        }

        public var detectedPath: String? {
            guard let exe = executableName else { return nil }
            return AIAgentDiscovery.resolvedPath(binaryName: exe)
        }

        public var detectedVersion: String? {
            guard let exe = executableName else { return nil }
            return AIAgentDiscovery.resolvedVersion(binaryName: exe)
        }

        public var capabilities: [String] {
            switch self {
            case .antigravity:
                return [
                    "대규모 리팩토링 및 다중 파일 수정 최적화",
                    "Google DeepMind 고속 컨텍스트 스트리밍",
                    "자동 컴파일 & 단위 테스트 루프 지원"
                ]
            case .claude:
                return [
                    "Claude 3.7 Sonnet 하이브리드 추론 지원",
                    "대화형 REPL 터미널 및 파일 편집 브릿지",
                    "Anthropic API 직접 연동"
                ]
            case .aider, .cursor:
                return [
                    "Git Repo Map 기반 문맥 압축 전송",
                    "Cursor IDE 에디터 소켓 동기화",
                    "로컬 데몬 백그라운드 리스닝"
                ]
            case .codex:
                return [
                    "OpenAI Codex 코드 생성 엔진",
                    "빠른 인라인 자동완성 지원",
                    "경량화된 CLI 작업 수행"
                ]
            case .goose, .openhands:
                return [
                    "자율 에이전트 다중 스텝 실행",
                    "로컬 도구 및 터미널 권한 위임",
                    "오픈소스 에이전트 프레임워크 연동"
                ]
            case .custom:
                return [
                    "사용자 정의 CLI 명령어 직접 실행",
                    "환경 변수 및 파이프라인 전달",
                    "임의의 로컬 자동화 스크립트 트리거"
                ]
            }
        }

        public var latencyHint: String {
            switch self {
            case .antigravity: return "18ms"
            case .claude: return "24ms"
            case .aider, .cursor: return "35ms"
            case .codex: return "28ms"
            default: return "30ms"
            }
        }

        public var shortcutHint: String {
            switch self {
            case .antigravity: return "⌥ Space"
            case .claude: return "⌥ C"
            case .aider, .cursor: return "⌥ A"
            default: return "⌥ ↵"
            }
        }

        /// 이 AI 에이전트가 저장소 루트에서 실제로 읽는 지침(규칙) 파일명
        public var guidelineFileName: String {
            switch self {
            case .claude: return "CLAUDE.md"
            case .codex: return "AGENTS.md"
            case .antigravity: return "AGENTS.md"
            case .cursor: return ".cursorrules"
            case .aider: return "CONVENTIONS.md"
            case .goose: return ".goosehints"
            case .openhands: return "AGENTS.md"
            case .custom: return "AGENTS.md"
            }
        }
    }

    public enum TerminalApp: String, Codable, CaseIterable, Sendable, Identifiable {
        case iTerm = "iTerm2 스타일 (추천)"
        case embedded = "VS Code 다크 스타일"
        case terminal = "macOS Terminal 스타일"
        case ghostty = "Ghostty 스타일"

        public var id: String { rawValue }

        public var shortName: String {
            switch self {
            case .iTerm: return "iTerm2"
            case .embedded: return "VS Code"
            case .terminal: return "Terminal"
            case .ghostty: return "Ghostty"
            }
        }

        public var termProgramEnv: String {
            switch self {
            case .iTerm: return "iTerm.app"
            case .embedded: return "vscode"
            case .terminal: return "Apple_Terminal"
            case .ghostty: return "ghostty"
            }
        }

        public var bundleIdentifier: String {
            switch self {
            case .embedded, .terminal: return "com.apple.Terminal"
            case .iTerm: return "com.googlecode.iterm2"
            case .ghostty: return "com.mitchellh.ghostty"
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawString = (try? container.decode(String.self)) ?? ""
            switch rawString {
            case "iTerm2", "iTerm", "iTerm2 스타일", "iTerm2 스타일 (추천)":
                self = .iTerm
            case "앱 내장 터미널 (VS Code 스타일)", "앱 내장 터미널 (추천)", "VS Code 다크 스타일", "embedded":
                self = .embedded
            case "macOS Terminal", "Terminal", "macOS Terminal 스타일":
                self = .terminal
            case "Ghostty", "ghostty", "Ghostty 스타일":
                self = .ghostty
            default:
                self = .iTerm
            }
        }
    }

    public var aiAgentPreset: AIAgentPreset
    public var dangerouslySkipPermissions: Bool
    public var customCliTemplate: String
    public var terminalApp: TerminalApp
    public var defaultProjectsDirectory: String
    public var customPromptTemplate: String

    public var criticalThresholdDays: Int
    public var autoCommitOnTaskCompletion: Bool
    public var streamInEmbeddedTerminal: Bool
    public var weeklyReportEnabled: Bool

    // MARK: - Voice Assistant
    public enum TTSEngine: String, Codable, CaseIterable, Sendable, Identifiable {
        case apple = "Apple (내장)"
        case melo = "MeloTTS (로컬)"

        public var id: String { rawValue }
    }

    /// 사용할 음성 합성 엔진
    public var ttsEngine: TTSEngine
    /// 선택된 음성 합성 보이스 식별자. nil이면 자동으로 최적의 한국어 보이스를 선택합니다.
    public var voiceIdentifier: String?
    /// 말하기 속도 (0.0 가장 느림 ~ 1.0 가장 빠름, 기본값 0.5)
    public var voiceSpeechRate: Float

    // MARK: - Monitored Repositories
    public var monitoredRepoIds: Set<Int>?
    public var ignoredRepoIds: Set<Int>
    public var hasCompletedInitialSelection: Bool

    public func isRepoMonitored(_ repoId: Int) -> Bool {
        guard hasCompletedInitialSelection else { return false }
        if ignoredRepoIds.contains(repoId) {
            return false
        }
        if let monitored = monitoredRepoIds {
            return monitored.contains(repoId)
        }
        return true
    }

    public init(
        githubToken: String = "",
        staleThresholdDays: Int = 14,
        warningThresholdDays: Int = 7,
        criticalThresholdDays: Int = 30,
        isDockBadgeEnabled: Bool = true,
        isNotificationEnabled: Bool = true,
        excludeArchived: Bool = true,
        excludeForks: Bool = false,
        autoRefreshIntervalMinutes: Int = 60,
        aiAgentPreset: AIAgentPreset = .claude,
        dangerouslySkipPermissions: Bool = true,
        autoCommitOnTaskCompletion: Bool = true,
        streamInEmbeddedTerminal: Bool = true,
        weeklyReportEnabled: Bool = true,
        customCliTemplate: String = "claude --dangerously-skip-permissions \"{prompt}\"",
        terminalApp: TerminalApp = .iTerm,
        defaultProjectsDirectory: String = "~/Documents",
        customPromptTemplate: String = """
[작업 목표] {memo_title}
[세부 내용] {memo_content}
[저장소] {repo_name} (언어: {language})
위 내용을 바탕으로 현재 프로젝트의 코드를 검토하고 해당 기능 개발 및 수정을 진행해 주세요.
""",
        monitoredRepoIds: Set<Int>? = nil,
        ignoredRepoIds: Set<Int> = [],
        hasCompletedInitialSelection: Bool = false,
        ttsEngine: TTSEngine = .apple,
        voiceIdentifier: String? = nil,
        voiceSpeechRate: Float = 0.5
    ) {
        self.githubToken = githubToken
        self.staleThresholdDays = staleThresholdDays
        self.warningThresholdDays = warningThresholdDays
        self.criticalThresholdDays = criticalThresholdDays
        self.isDockBadgeEnabled = isDockBadgeEnabled
        self.isNotificationEnabled = isNotificationEnabled
        self.excludeArchived = excludeArchived
        self.excludeForks = excludeForks
        self.autoRefreshIntervalMinutes = autoRefreshIntervalMinutes
        self.aiAgentPreset = aiAgentPreset
        self.dangerouslySkipPermissions = dangerouslySkipPermissions
        self.autoCommitOnTaskCompletion = autoCommitOnTaskCompletion
        self.streamInEmbeddedTerminal = streamInEmbeddedTerminal
        self.weeklyReportEnabled = weeklyReportEnabled
        self.customCliTemplate = customCliTemplate
        self.terminalApp = terminalApp
        self.defaultProjectsDirectory = defaultProjectsDirectory
        self.customPromptTemplate = customPromptTemplate
        self.monitoredRepoIds = monitoredRepoIds
        self.ignoredRepoIds = ignoredRepoIds
        self.hasCompletedInitialSelection = hasCompletedInitialSelection
        self.ttsEngine = ttsEngine
        self.voiceIdentifier = voiceIdentifier
        self.voiceSpeechRate = voiceSpeechRate
    }

    // MARK: - Decodable Backward Compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.githubToken = try container.decodeIfPresent(String.self, forKey: .githubToken) ?? ""
        self.staleThresholdDays = try container.decodeIfPresent(Int.self, forKey: .staleThresholdDays) ?? 14
        self.warningThresholdDays = try container.decodeIfPresent(Int.self, forKey: .warningThresholdDays) ?? 7
        self.criticalThresholdDays = try container.decodeIfPresent(Int.self, forKey: .criticalThresholdDays) ?? 30
        self.isDockBadgeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDockBadgeEnabled) ?? true
        self.isNotificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .isNotificationEnabled) ?? true
        self.excludeArchived = try container.decodeIfPresent(Bool.self, forKey: .excludeArchived) ?? true
        self.excludeForks = try container.decodeIfPresent(Bool.self, forKey: .excludeForks) ?? false
        self.autoRefreshIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .autoRefreshIntervalMinutes) ?? 60
        self.aiAgentPreset = try container.decodeIfPresent(AIAgentPreset.self, forKey: .aiAgentPreset) ?? .claude
        self.dangerouslySkipPermissions = try container.decodeIfPresent(Bool.self, forKey: .dangerouslySkipPermissions) ?? true
        self.autoCommitOnTaskCompletion = try container.decodeIfPresent(Bool.self, forKey: .autoCommitOnTaskCompletion) ?? true
        self.streamInEmbeddedTerminal = try container.decodeIfPresent(Bool.self, forKey: .streamInEmbeddedTerminal) ?? true
        self.weeklyReportEnabled = try container.decodeIfPresent(Bool.self, forKey: .weeklyReportEnabled) ?? true
        self.customCliTemplate = try container.decodeIfPresent(String.self, forKey: .customCliTemplate) ?? "claude --dangerously-skip-permissions \"{prompt}\""
        self.terminalApp = try container.decodeIfPresent(TerminalApp.self, forKey: .terminalApp) ?? .iTerm
        self.defaultProjectsDirectory = try container.decodeIfPresent(String.self, forKey: .defaultProjectsDirectory) ?? "~/Documents"
        self.customPromptTemplate = try container.decodeIfPresent(String.self, forKey: .customPromptTemplate) ?? """
[작업 목표] {memo_title}
[세부 내용] {memo_content}
[저장소] {repo_name} (언어: {language})
위 내용을 바탕으로 현재 프로젝트의 코드를 검토하고 해당 기능 개발 및 수정을 진행해 주세요.
"""
        self.monitoredRepoIds = try container.decodeIfPresent(Set<Int>.self, forKey: .monitoredRepoIds)
        self.ignoredRepoIds = try container.decodeIfPresent(Set<Int>.self, forKey: .ignoredRepoIds) ?? []
        self.hasCompletedInitialSelection = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedInitialSelection) ?? false
        self.ttsEngine = try container.decodeIfPresent(TTSEngine.self, forKey: .ttsEngine) ?? .apple
        self.voiceIdentifier = try container.decodeIfPresent(String.self, forKey: .voiceIdentifier)
        self.voiceSpeechRate = try container.decodeIfPresent(Float.self, forKey: .voiceSpeechRate) ?? 0.5
    }

    public static let `default` = AppSettings()
}

/// 시스템에 설치된 AI CLI 도구를 빠르고 안전하게 감지하는 유틸리티
public enum AIAgentDiscovery: Sendable {
    private static let lock = NSLock()
    private static var searchPathsCache: [String]?
    private static var installedCache: [String: (isInstalled: Bool, checkedAt: Date)] = [:]
    private static var versionCache: [String: String] = [:]
    private static let cacheTTL: TimeInterval = 10.0 // 10초간 결과 캐싱하여 반복 디스크 I/O 방지

    /// 실행 파일 탐색 기본 경로 목록
    public static func searchPaths() -> [String] {
        lock.lock()
        defer { lock.unlock() }

        if let cached = searchPathsCache {
            return cached
        }

        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path

        var dirs: [String] = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "\(home)/bin",
            "\(home)/.local/bin",
            "\(home)/.cargo/bin",
            "\(home)/.gemini/antigravity-cli/bin",
            "\(home)/.bun/bin",
            "\(home)/.yarn/bin",
            "\(home)/.npm-global/bin",
            "\(home)/Library/pnpm",
            "\(home)/.local/share/mise/shims",
            "\(home)/.asdf/shims",
            "\(home)/.volta/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        if let envPath = ProcessInfo.processInfo.environment["PATH"] {
            for p in envPath.split(separator: ":").map(String.init) {
                if !dirs.contains(p) {
                    dirs.append(p)
                }
            }
        }

        // nvm 버전별 node bin 디렉토리도 자동 탐색 (~/.nvm/versions/node/*/bin)
        let nvmDir = "\(home)/.nvm/versions/node"
        if let subdirs = try? fileManager.contentsOfDirectory(atPath: nvmDir) {
            for sub in subdirs {
                let binPath = "\(nvmDir)/\(sub)/bin"
                if fileManager.fileExists(atPath: binPath) && !dirs.contains(binPath) {
                    dirs.append(binPath)
                }
            }
        }

        searchPathsCache = dirs
        return dirs
    }

    /// 바이너리의 절대 경로 반환
    public static func resolvedPath(binaryName: String) -> String? {
        let fileManager = FileManager.default
        for dir in searchPaths() {
            let fullPath = "\(dir)/\(binaryName)"
            if fileManager.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    /// 바이너리의 버전 문자열 반환 (예: "v2.1.236", "v1.1.27")
    public static func resolvedVersion(binaryName: String) -> String? {
        lock.lock()
        if let ver = versionCache[binaryName] {
            lock.unlock()
            return ver
        }
        lock.unlock()

        guard let path = resolvedPath(binaryName: binaryName) else { return nil }

        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPaths().joined(separator: ":")
        process.environment = env

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    let firstLine = str.components(separatedBy: .newlines).first ?? str
                    let clean = firstLine.replacingOccurrences(of: "(Claude Code)", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let formatted = clean.hasPrefix("v") ? clean : "v\(clean)"
                    lock.lock()
                    versionCache[binaryName] = formatted
                    lock.unlock()
                    return formatted
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    /// 주어진 CLI 바이너리가 현재 시스템에 설치되어 있는지 확인
    public static func isInstalled(binaryName: String) -> Bool {
        lock.lock()
        if let entry = installedCache[binaryName], Date().timeIntervalSince(entry.checkedAt) < cacheTTL {
            let result = entry.isInstalled
            lock.unlock()
            return result
        }
        lock.unlock()

        let fileManager = FileManager.default
        var exists = false

        // 1. 주요 설치 디렉토리에서 빠른 파일 검사
        for dir in searchPaths() {
            let fullPath = "\(dir)/\(binaryName)"
            if fileManager.isExecutableFile(atPath: fullPath) {
                exists = true
                break
            }
        }

        // 2. 미발견 시 /usr/bin/which 로 폴백 확인
        if !exists {
            let pipe = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [binaryName]
            process.standardOutput = pipe
            process.standardError = Pipe()
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = searchPaths().joined(separator: ":")
            process.environment = env

            do {
                try process.run()
                process.waitUntilExit()
                exists = (process.terminationStatus == 0)
            } catch {
                exists = false
            }
        }

        lock.lock()
        installedCache[binaryName] = (isInstalled: exists, checkedAt: Date())
        lock.unlock()

        return exists
    }

    /// 캐시 무효화
    public static func invalidateCache() {
        lock.lock()
        defer { lock.unlock() }
        searchPathsCache = nil
        installedCache.removeAll()
        versionCache.removeAll()
    }
}
