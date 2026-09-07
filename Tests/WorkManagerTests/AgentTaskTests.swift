import XCTest
@testable import WorkManager

final class MockTerminalExecutionService: TerminalExecutionServiceProtocol, @unchecked Sendable {
    var executedCommand: String?
    var executedDirectory: String?
    var executedApp: AppSettings.TerminalApp?
    var executedScript: String?

    func executeInTerminal(command: String, workingDirectory: String, terminalApp: AppSettings.TerminalApp) throws {
        self.executedCommand = command
        self.executedDirectory = workingDirectory
        self.executedApp = terminalApp
    }

    func executeScript(scriptContent: String, workingDirectory: String?, terminalApp: AppSettings.TerminalApp) throws {
        self.executedScript = scriptContent
        self.executedDirectory = workingDirectory
        self.executedCommand = scriptContent
        self.executedApp = terminalApp
    }
}

final class AgentTaskExecutionTests: XCTestCase {
    private var mockTerminal: MockTerminalExecutionService!
    private var mockMemoRepo: MockMemoRepository!
    private var useCase: ExecuteAgentTaskUseCase!

    override func setUp() {
        super.setUp()
        mockTerminal = MockTerminalExecutionService()
        mockMemoRepo = MockMemoRepository()
        useCase = ExecuteAgentTaskUseCase(terminalService: mockTerminal, memoRepository: mockMemoRepo)
    }

    func testBuildPromptSubstitutesVariables() {
        let repo = RepositoryItem(
            id: 1,
            name: "workmanager",
            fullName: "user/workmanager",
            owner: "user",
            htmlUrl: URL(string: "https://github.com")!,
            defaultBranch: "main",
            language: "Swift"
        )
        let memo = MemoItem(
            repositoryId: 1,
            title: "다크 모드 지원",
            content: "시스템 설정에 맞춰 테마 변경"
        )

        let template = "Repo: {repo_name}, Task: {memo_title}, Detail: {memo_content}, Lang: {language}"
        let prompt = useCase.buildPrompt(repository: repo, memo: memo, template: template)

        XCTAssertEqual(prompt, "Repo: user/workmanager, Task: 다크 모드 지원, Detail: 시스템 설정에 맞춰 테마 변경, Lang: Swift")
    }

    func testBuildCommandWithAntigravityPresetDefaultSkipPermissions() {
        let settings = AppSettings(aiAgentPreset: .antigravity, dangerouslySkipPermissions: true)
        let command = useCase.buildCommand(prompt: "버그 수정", settings: settings)
        XCTAssertEqual(command, "agy --dangerously-skip-permissions -i \"버그 수정\"")
    }

    func testBuildCommandWithClaudePresetDefaultSkipPermissions() {
        let settings = AppSettings(aiAgentPreset: .claude, dangerouslySkipPermissions: true)
        let command = useCase.buildCommand(prompt: "버그 수정", settings: settings)
        XCTAssertEqual(command, "claude --dangerously-skip-permissions \"버그 수정\"")
    }

    func testBuildCommandWithoutSkipPermissions() {
        let settings = AppSettings(aiAgentPreset: .claude, dangerouslySkipPermissions: false)
        let command = useCase.buildCommand(prompt: "버그 수정", settings: settings)
        XCTAssertEqual(command, "claude \"버그 수정\"")
    }

    func testBuildCommandWithOverridePreset() {
        let settings = AppSettings(aiAgentPreset: .claude, dangerouslySkipPermissions: true)
        let command = useCase.buildCommand(prompt: "새 기능 개발", settings: settings, overridePreset: .codex)
        XCTAssertEqual(command, "codex --dangerously-skip-permissions \"새 기능 개발\"")
    }

    func testExecuteTaskUpdatesMemoStatusToInProgress() async throws {
        let repo = RepositoryItem(
            id: 2,
            name: "test-repo",
            fullName: "user/test-repo",
            owner: "user",
            htmlUrl: URL(string: "https://github.com")!
        )
        let memo = MemoItem(
            repositoryId: 2,
            title: "OAuth 연동",
            content: "Apple 로그인 구현"
        )
        try await mockMemoRepo.saveMemo(memo)

        let settings = AppSettings(aiAgentPreset: .antigravity, terminalApp: .terminal)
        let updated = try await useCase.execute(
            repository: repo,
            memo: memo,
            localPath: "/Users/test/Projects/test-repo",
            settings: settings
        )

        XCTAssertEqual(updated.status, .inProgress)
        XCTAssertNotNil(updated.lastExecutedAt)
        XCTAssertTrue(mockTerminal.executedCommand?.contains("agy --dangerously-skip-permissions -i") == true)
        XCTAssertEqual(mockTerminal.executedDirectory, "/Users/test/Projects/test-repo")
    }

    func testBuildBatchPromptCombinesMultipleMemos() {
        let repo = RepositoryItem(
            id: 1,
            name: "workmanager",
            fullName: "user/workmanager",
            owner: "user",
            htmlUrl: URL(string: "https://github.com")!,
            defaultBranch: "main",
            language: "Swift"
        )
        let memo1 = MemoItem(
            repositoryId: 1,
            title: "다크모드 지원",
            content: "테마 설정 연동",
            priority: .high
        )
        let memo2 = MemoItem(
            repositoryId: 1,
            title: "독 뱃지 카운트",
            content: "방치 저장소 숫자 표기",
            priority: .medium
        )

        let prompt = useCase.buildBatchPrompt(repository: repo, memos: [memo1, memo2], template: "")
        XCTAssertTrue(prompt.contains("[선택된 작업 항목 (2건)]"))
        XCTAssertTrue(prompt.contains("1. [중요도: 높음] 다크모드 지원"))
        XCTAssertTrue(prompt.contains("2. [중요도: 보통] 독 뱃지 카운트"))
        XCTAssertTrue(prompt.contains("user/workmanager"))
    }

    func testExecuteBatchUpdatesAllSelectedMemos() async throws {
        let repo = RepositoryItem(
            id: 3,
            name: "batch-repo",
            fullName: "user/batch-repo",
            owner: "user",
            htmlUrl: URL(string: "https://github.com")!
        )
        let memo1 = MemoItem(repositoryId: 3, title: "작업1")
        let memo2 = MemoItem(repositoryId: 3, title: "작업2")
        try await mockMemoRepo.saveMemo(memo1)
        try await mockMemoRepo.saveMemo(memo2)

        let settings = AppSettings(aiAgentPreset: .claude)
        let updatedList = try await useCase.executeBatch(
            repository: repo,
            memos: [memo1, memo2],
            localPath: "/Users/test/batch-repo",
            settings: settings
        )

        XCTAssertEqual(updatedList.count, 2)
        XCTAssertTrue(updatedList.allSatisfy { $0.status == .inProgress })
        XCTAssertTrue(mockTerminal.executedCommand?.contains("claude --dangerously-skip-permissions") == true)
        XCTAssertEqual(mockTerminal.executedDirectory, "/Users/test/batch-repo")
    }
}

// MARK: - Multi-Tab Terminal & Auto-New Tab for Different Agents Tests
final class TerminalMultiTabTests: XCTestCase {
    private var manager: TerminalSessionManager!

    override func setUp() {
        super.setUp()
        manager = TerminalSessionManager()
    }

    override func tearDown() {
        manager.closeSession(for: 999)
        super.tearDown()
    }

    func testGroupCreatesInitialDefaultTab() {
        let group = manager.getOrCreateGroup(for: 999, name: "TestRepo", localPath: "/tmp")
        XCTAssertEqual(group.tabs.count, 1)
        XCTAssertEqual(group.tabs.first?.title, "터미널")
        XCTAssertNil(group.tabs.first?.preset)
        XCTAssertEqual(group.activeTabId, group.tabs.first?.id)
    }

    func testExecuteTaskWithAgentAAssignsPresetToIdleTab() {
        let group = manager.getOrCreateGroup(for: 999, name: "TestRepo", localPath: "/tmp")
        manager.executeCommand(command: "echo test", repositoryId: 999, name: "TestRepo", localPath: "/tmp", preset: .antigravity)

        XCTAssertEqual(group.tabs.count, 1)
        let tab = group.activeTab
        XCTAssertEqual(tab?.preset, .antigravity)
        XCTAssertEqual(tab?.title, "Antigravity")
        XCTAssertTrue(tab?.hasExecutedTask == true)
    }

    func testSequentialAgentAThenAgentBSpawnsNewTab() {
        let group = manager.getOrCreateGroup(for: 999, name: "TestRepo", localPath: "/tmp")

        // 1. Agent A (Antigravity) 실행
        manager.executeCommand(command: "echo 'Agent A'", repositoryId: 999, name: "TestRepo", localPath: "/tmp", preset: .antigravity)
        XCTAssertEqual(group.tabs.count, 1)
        XCTAssertEqual(group.activeTab?.preset, .antigravity)

        // 2. 다른 에이전트 B (Claude) 신규 실행 시 새로운 탭 자동 생성 확인
        manager.executeCommand(command: "echo 'Agent B'", repositoryId: 999, name: "TestRepo", localPath: "/tmp", preset: .claude)

        XCTAssertEqual(group.tabs.count, 2, "Agent A 작업 후 Agent B 작업 요청 시 별도의 신규 터미널 탭이 생성되어야 합니다.")
        XCTAssertEqual(group.tabs[0].preset, .antigravity)
        XCTAssertEqual(group.tabs[1].preset, .claude)
        XCTAssertEqual(group.activeTabId, group.tabs[1].id, "새로 생성된 Agent B 탭이 활성 탭으로 전환되어야 합니다.")
    }

    func testBusyTabSpawnsNewTabForConcurrentExecution() {
        let group = manager.getOrCreateGroup(for: 999, name: "TestRepo", localPath: "/tmp")

        // 탭 1 실행 및 busy 상태 시뮬레이션
        manager.executeCommand(command: "echo 'Task 1'", repositoryId: 999, name: "TestRepo", localPath: "/tmp", preset: .claude)
        group.activeTab?.isRunning = true

        // 탭 1이 실행 중인 상태에서 다시 Claude 작업 요청
        manager.executeCommand(command: "echo 'Task 2'", repositoryId: 999, name: "TestRepo", localPath: "/tmp", preset: .claude)

        XCTAssertEqual(group.tabs.count, 2, "기존 탭이 실행 중인 경우 충돌 방지를 위해 새 탭이 생성되어야 합니다.")
        XCTAssertEqual(group.activeTabId, group.tabs[1].id)
    }

    func testCloseTabAndFallback() {
        let group = manager.getOrCreateGroup(for: 999, name: "TestRepo", localPath: "/tmp")
        let tab2 = group.createTab(preset: .codex)
        XCTAssertEqual(group.tabs.count, 2)
        XCTAssertEqual(group.activeTabId, tab2.id)

        // 탭 2 닫기
        group.closeTab(id: tab2.id)
        XCTAssertEqual(group.tabs.count, 1)
        XCTAssertEqual(group.activeTabId, group.tabs[0].id)

        // 마지막 탭 닫기 -> 새로운 기본 탭 자동 생성
        group.closeTab(id: group.tabs[0].id)
        XCTAssertEqual(group.tabs.count, 1)
        XCTAssertEqual(group.tabs[0].title, "터미널")
    }

    func testTerminalProfileStylingAndDynamicUpdate() {
        let group = manager.getOrCreateGroup(for: 999, name: "TestRepo", localPath: "/tmp")
        let tab = group.activeTab
        XCTAssertNotNil(tab)

        // 1. 기본 프로필 iTerm2 스타일 검증
        tab?.applyProfile(.iTerm)
        XCTAssertEqual(tab?.profile, .iTerm)
        XCTAssertEqual(tab?.profile.termProgramEnv, "iTerm.app")

        // 2. VS Code 프로필 변경 검증
        tab?.applyProfile(.embedded)
        XCTAssertEqual(tab?.profile, .embedded)
        XCTAssertEqual(tab?.profile.termProgramEnv, "vscode")
        XCTAssertEqual(tab?.terminalView.caretColor, NSColor.systemTeal)

        // 3. TerminalSessionManager 전체 프로필 일괄 적용 검증
        manager.applyTerminalProfile(.terminal)
        XCTAssertEqual(manager.currentProfile, .terminal)
        XCTAssertEqual(tab?.profile, .terminal)
        XCTAssertEqual(tab?.terminalView.caretColor, NSColor.white)
    }
}
