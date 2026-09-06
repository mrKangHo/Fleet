import Foundation

/// 선택한 메모를 기반으로 AI Agent 작업을 구성하고 터미널에서 실행하는 Use Case
public struct ExecuteAgentTaskUseCase: Sendable {
    private let terminalService: TerminalExecutionServiceProtocol
    private let memoRepository: MemoRepositoryProtocol

    public init(
        terminalService: TerminalExecutionServiceProtocol,
        memoRepository: MemoRepositoryProtocol
    ) {
        self.terminalService = terminalService
        self.memoRepository = memoRepository
    }

    /// 프롬프트 내용 구성
    public func buildPrompt(
        repository: RepositoryItem,
        memo: MemoItem,
        template: String
    ) -> String {
        return template
            .replacingOccurrences(of: "{memo_title}", with: memo.title)
            .replacingOccurrences(of: "{memo_content}", with: memo.content.isEmpty ? "별도 세부사항 없음" : memo.content)
            .replacingOccurrences(of: "{repo_name}", with: repository.fullName)
            .replacingOccurrences(of: "{language}", with: repository.language ?? "기타")
            .replacingOccurrences(of: "{branch}", with: repository.defaultBranch)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 여러 개 선택된 메모들을 종합하여 하나의 통합 프롬프트 생성
    public func buildBatchPrompt(
        repository: RepositoryItem,
        memos: [MemoItem],
        template: String
    ) -> String {
        if memos.count == 1, let single = memos.first {
            return buildPrompt(repository: repository, memo: single, template: template)
        }

        var taskList = ""
        for (index, memo) in memos.enumerated() {
            let priorityText = memo.priority.rawValue
            taskList += "\(index + 1). [중요도: \(priorityText)] \(memo.title)\n"
            if !memo.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                taskList += "   - 세부사항: \(memo.content.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            }
        }

        return """
[선택된 작업 항목 (\(memos.count)건)]
\(taskList.trimmingCharacters(in: .whitespacesAndNewlines))

[저장소] \(repository.fullName) (언어: \(repository.language ?? "기타"), 기본 브랜치: \(repository.defaultBranch))
위 선택된 \(memos.count)개 작업 항목들을 차례대로 검토하고 현재 프로젝트의 코드를 수정 및 개발해 주세요.
""".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// CLI 명령어 생성
    public func buildCommand(
        prompt: String,
        settings: AppSettings,
        overridePreset: AppSettings.AIAgentPreset? = nil
    ) -> String {
        let preset = overridePreset ?? settings.aiAgentPreset
        let template: String
        if preset == .custom {
            template = settings.customCliTemplate
        } else {
            template = preset.commandTemplate(dangerouslySkipPermissions: settings.dangerouslySkipPermissions)
        }

        // 터미널 한 줄 실행을 위해 줄바꿈을 공백으로 정리하고 큰따옴표 이스케이프
        let sanitizedPrompt = prompt
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return template.replacingOccurrences(of: "{prompt}", with: sanitizedPrompt)
    }

    /// 프롬프트를 Heredoc으로 완벽하게 보존하는 런처 스크립트 본문 생성 (필요 시 보조용)
    public func buildLauncherScript(
        repository: RepositoryItem,
        prompt: String,
        workingDirectory: String,
        settings: AppSettings,
        overridePreset: AppSettings.AIAgentPreset? = nil
    ) -> String {
        let preset = overridePreset ?? settings.aiAgentPreset
        let cliCommand: String

        if preset == .custom {
            if settings.customCliTemplate.contains("{prompt}") {
                cliCommand = settings.customCliTemplate.replacingOccurrences(of: "{prompt}", with: "$PROMPT")
            } else {
                cliCommand = "\(settings.customCliTemplate) \"$PROMPT\""
            }
        } else {
            let skip = settings.dangerouslySkipPermissions ? "--dangerously-skip-permissions " : ""
            switch preset {
            case .claude:
                cliCommand = "claude \(skip)\"$PROMPT\""
            case .antigravity:
                cliCommand = "agy \(skip)-i \"$PROMPT\""
            case .codex:
                cliCommand = "codex \(skip)\"$PROMPT\""
            case .cursor:
                cliCommand = "cursor \(skip)\"$PROMPT\""
            case .aider:
                let aiderSkip = settings.dangerouslySkipPermissions ? "--yes " : ""
                cliCommand = "aider \(aiderSkip)--message \"$PROMPT\""
            case .goose:
                cliCommand = "goose run --text \"$PROMPT\""
            case .openhands:
                cliCommand = "openhands \(skip)\"$PROMPT\""
            case .custom:
                cliCommand = "echo \"$PROMPT\""
            }
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let resolvedWorkingDir = workingDirectory.replacingOccurrences(of: "~", with: home)
        let escapedDir = "'\(resolvedWorkingDir.replacingOccurrences(of: "'", with: "'\\''"))'"

        return """
#!/bin/zsh
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 [WorkManager] AI Agent 작업 실행"
echo "📂 저장소: \(repository.fullName)"
echo "🤖 에이전트: \(preset.rawValue)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd \(escapedDir) || {
    echo "❌ 작업 디렉토리 이동 실패: \(resolvedWorkingDir)"
    exit 1
}

PROMPT=$(cat << 'WORKMANAGER_PROMPT_EOF'
\(prompt)
WORKMANAGER_PROMPT_EOF
)

\(cliCommand)
"""
    }

    /// 터미널에서 작업 실행 및 메모 상태 갱신
    @discardableResult
    public func execute(
        repository: RepositoryItem,
        memo: MemoItem,
        localPath: String,
        settings: AppSettings,
        overridePreset: AppSettings.AIAgentPreset? = nil
    ) async throws -> MemoItem {
        let prompt = buildPrompt(repository: repository, memo: memo, template: settings.customPromptTemplate)
        let command = buildCommand(prompt: prompt, settings: settings, overridePreset: overridePreset)

        // 터미널에서 AI 명령어 직접 직통 실행
        try terminalService.executeInTerminal(
            command: command,
            workingDirectory: localPath,
            terminalApp: settings.terminalApp
        )

        // 메모 상태를 작업 중(inProgress)으로 갱신
        var updatedMemo = memo
        updatedMemo.status = .inProgress
        updatedMemo.lastExecutedAt = Date()
        updatedMemo.updatedAt = Date()

        try await memoRepository.saveMemo(updatedMemo)
        return updatedMemo
    }

    /// 선택된 여러 개의 메모를 터미널에서 일괄 실행하고 상태 갱신
    @discardableResult
    public func executeBatch(
        repository: RepositoryItem,
        memos: [MemoItem],
        localPath: String,
        settings: AppSettings,
        overridePreset: AppSettings.AIAgentPreset? = nil
    ) async throws -> [MemoItem] {
        guard !memos.isEmpty else { return [] }

        let prompt = buildBatchPrompt(repository: repository, memos: memos, template: settings.customPromptTemplate)
        let command = buildCommand(prompt: prompt, settings: settings, overridePreset: overridePreset)

        // 터미널에서 AI 명령어 직접 직통 실행
        try terminalService.executeInTerminal(
            command: command,
            workingDirectory: localPath,
            terminalApp: settings.terminalApp
        )

        // 선택된 모든 메모 상태를 작업 중(inProgress)으로 갱신
        var updatedMemos: [MemoItem] = []
        let now = Date()
        for var memo in memos {
            memo.status = .inProgress
            memo.lastExecutedAt = now
            memo.updatedAt = now
            try await memoRepository.saveMemo(memo)
            updatedMemos.append(memo)
        }

        return updatedMemos
    }
}
