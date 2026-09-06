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
    }

    public enum TerminalApp: String, Codable, CaseIterable, Sendable {
        case terminal = "macOS Terminal"
        case iTerm = "iTerm2"
        case ghostty = "Ghostty"

        public var bundleIdentifier: String {
            switch self {
            case .terminal: return "com.apple.Terminal"
            case .iTerm: return "com.googlecode.iterm2"
            case .ghostty: return "com.mitchellh.ghostty"
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawString = (try? container.decode(String.self)) ?? ""
            switch rawString {
            case "macOS Terminal", "Terminal":
                self = .terminal
            case "iTerm2", "iTerm":
                self = .iTerm
            case "Ghostty", "ghostty":
                self = .ghostty
            default:
                self = .terminal
            }
        }
    }

    public var aiAgentPreset: AIAgentPreset
    public var dangerouslySkipPermissions: Bool
    public var customCliTemplate: String
    public var terminalApp: TerminalApp
    public var defaultProjectsDirectory: String
    public var customPromptTemplate: String

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
        staleThresholdDays: Int = 30,
        warningThresholdDays: Int = 14,
        isDockBadgeEnabled: Bool = true,
        isNotificationEnabled: Bool = true,
        excludeArchived: Bool = true,
        excludeForks: Bool = false,
        autoRefreshIntervalMinutes: Int = 60,
        aiAgentPreset: AIAgentPreset = .claude,
        dangerouslySkipPermissions: Bool = true,
        customCliTemplate: String = "claude --dangerously-skip-permissions \"{prompt}\"",
        terminalApp: TerminalApp = .terminal,
        defaultProjectsDirectory: String = "~/Documents",
        customPromptTemplate: String = """
[작업 목표] {memo_title}
[세부 내용] {memo_content}
[저장소] {repo_name} (언어: {language})
위 내용을 바탕으로 현재 프로젝트의 코드를 검토하고 해당 기능 개발 및 수정을 진행해 주세요.
""",
        monitoredRepoIds: Set<Int>? = nil,
        ignoredRepoIds: Set<Int> = [],
        hasCompletedInitialSelection: Bool = false
    ) {
        self.githubToken = githubToken
        self.staleThresholdDays = staleThresholdDays
        self.warningThresholdDays = warningThresholdDays
        self.isDockBadgeEnabled = isDockBadgeEnabled
        self.isNotificationEnabled = isNotificationEnabled
        self.excludeArchived = excludeArchived
        self.excludeForks = excludeForks
        self.autoRefreshIntervalMinutes = autoRefreshIntervalMinutes
        self.aiAgentPreset = aiAgentPreset
        self.dangerouslySkipPermissions = dangerouslySkipPermissions
        self.customCliTemplate = customCliTemplate
        self.terminalApp = terminalApp
        self.defaultProjectsDirectory = defaultProjectsDirectory
        self.customPromptTemplate = customPromptTemplate
        self.monitoredRepoIds = monitoredRepoIds
        self.ignoredRepoIds = ignoredRepoIds
        self.hasCompletedInitialSelection = hasCompletedInitialSelection
    }

    // MARK: - Decodable Backward Compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.githubToken = try container.decodeIfPresent(String.self, forKey: .githubToken) ?? ""
        self.staleThresholdDays = try container.decodeIfPresent(Int.self, forKey: .staleThresholdDays) ?? 30
        self.warningThresholdDays = try container.decodeIfPresent(Int.self, forKey: .warningThresholdDays) ?? 14
        self.isDockBadgeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDockBadgeEnabled) ?? true
        self.isNotificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .isNotificationEnabled) ?? true
        self.excludeArchived = try container.decodeIfPresent(Bool.self, forKey: .excludeArchived) ?? true
        self.excludeForks = try container.decodeIfPresent(Bool.self, forKey: .excludeForks) ?? false
        self.autoRefreshIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .autoRefreshIntervalMinutes) ?? 60
        self.aiAgentPreset = try container.decodeIfPresent(AIAgentPreset.self, forKey: .aiAgentPreset) ?? .claude
        self.dangerouslySkipPermissions = try container.decodeIfPresent(Bool.self, forKey: .dangerouslySkipPermissions) ?? true
        self.customCliTemplate = try container.decodeIfPresent(String.self, forKey: .customCliTemplate) ?? "claude --dangerously-skip-permissions \"{prompt}\""
        self.terminalApp = try container.decodeIfPresent(TerminalApp.self, forKey: .terminalApp) ?? .terminal
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
    }

    public static let `default` = AppSettings()
}
