import Foundation
import SwiftUI

@MainActor
public final class RepositoryDetailViewModel: ObservableObject {
    public let environment: AppEnvironment

    @Published public var repository: RepositoryItem?
    @Published public var memos: [MemoItem] = []
    @Published public var selectedMemoIds: Set<UUID> = []
    @Published public var isLoadingMemos: Bool = false
    @Published public var isLoadingCommit: Bool = false
    @Published public var localDirectoryPath: String?
    @Published public var isExecutingTask: Bool = false
    @Published public var successMessage: String?
    @Published public var errorMessage: String?

    // MARK: - AI Guideline State
    @Published public var isGuidelineSheetPresented: Bool = false
    @Published public var guidelineSelectedPreset: AppSettings.AIAgentPreset = .claude
    @Published public var guidelineContent: String = ""

    // 인라인 메모 입력 상태
    @Published public var newMemoTitle: String = ""
    @Published public var newMemoContent: String = ""
    @Published public var newMemoPriority: MemoItem.Priority = .medium

    public init(environment: AppEnvironment = .shared) {
        self.environment = environment
    }

    public func openInExternalTerminal() {
        guard let path = localDirectoryPath else { return }
        let settings = environment.settingsRepository.loadSettings()
        let app = settings.terminalApp == .embedded ? .terminal : settings.terminalApp
        try? environment.terminalExecutionService.executeInTerminal(
            command: "",
            workingDirectory: path,
            terminalApp: app
        )
    }

    public func setRepository(_ repo: RepositoryItem?) {
        self.repository = repo
        self.newMemoTitle = ""
        self.newMemoContent = ""
        self.selectedMemoIds.removeAll()
        self.errorMessage = nil
        self.successMessage = nil

        if let repo = repo {
            // 로컬 디렉토리 경로 로드 또는 자동 감지
            let savedPath = environment.localPathRepository.getLocalPath(for: repo.id)
            if let savedPath = savedPath, FileManager.default.fileExists(atPath: savedPath) {
                self.localDirectoryPath = savedPath
            } else {
                let settings = environment.settingsRepository.loadSettings()
                let detected = environment.localPathRepository.detectLocalPath(
                    for: repo.name,
                    baseDirectories: [settings.defaultProjectsDirectory, "~/Documents", "~/Projects", "~/Developer"]
                )
                self.localDirectoryPath = detected
                if let detected = detected {
                    environment.localPathRepository.setLocalPath(detected, for: repo.id)
                }
            }

            environment.terminalSessionManager.activeRepositoryId = repo.id
            if let path = self.localDirectoryPath {
                _ = environment.terminalSessionManager.getOrCreateSession(for: repo.id, name: repo.name, localPath: path)
            }

            Task {
                await loadMemos(for: repo.id)
                await fetchLatestCommitIfNeeded(for: repo)
            }
        } else {
            self.memos = []
            self.localDirectoryPath = nil
            environment.terminalSessionManager.activeRepositoryId = nil
        }
    }

    public func loadMemos(for repoId: Int) async {
        isLoadingMemos = true
        do {
            self.memos = try await environment.manageMemoUseCase.getMemos(for: repoId)
        } catch {
            self.errorMessage = "메모를 불러오는데 실패했습니다: \(error.localizedDescription)"
        }
        isLoadingMemos = false
    }

    public func addMemo() async -> Int {
        guard let repo = repository else { return 0 }
        let title = newMemoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return memos.count }

        do {
            let newMemo = try await environment.manageMemoUseCase.addMemo(
                repositoryId: repo.id,
                title: title,
                content: newMemoContent,
                priority: newMemoPriority
            )
            self.memos.insert(newMemo, at: 0)
            self.newMemoTitle = ""
            self.newMemoContent = ""
            self.newMemoPriority = .medium
            return self.memos.count
        } catch {
            self.errorMessage = "메모 저장 실패: \(error.localizedDescription)"
            return self.memos.count
        }
    }

    public func toggleCompletion(for memo: MemoItem) async {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        let original = memos[index]
        var target = original
        target.isCompleted.toggle()
        target.updatedAt = Date()
        // 1. 낙관적 UI 갱신 (지연 없는 60fps 애니메이션)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            self.memos[index] = target
        }

        do {
            try await environment.manageMemoUseCase.updateMemo(target)
        } catch {
            // 실패 시 롤백
            if let rollbackIndex = memos.firstIndex(where: { $0.id == memo.id }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    memos[rollbackIndex] = original
                }
            }
            self.errorMessage = "상태 변경 실패: \(error.localizedDescription)"
        }
    }

    public func updateMemoStatus(for memo: MemoItem, newStatus: MemoItem.Status) async {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        let original = memos[index]
        var target = original
        target.status = newStatus
        target.updatedAt = Date()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            self.memos[index] = target
        }

        do {
            try await environment.manageMemoUseCase.updateMemo(target)
        } catch {
            if let rollbackIndex = memos.firstIndex(where: { $0.id == memo.id }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    memos[rollbackIndex] = original
                }
            }
            self.errorMessage = "상태 변경 실패: \(error.localizedDescription)"
        }
    }

    public func updateMemoPriority(for memo: MemoItem, newPriority: MemoItem.Priority) async {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        let original = memos[index]
        var target = original
        target.priority = newPriority
        target.updatedAt = Date()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            self.memos[index] = target
        }

        do {
            try await environment.manageMemoUseCase.updateMemo(target)
        } catch {
            if let rollbackIndex = memos.firstIndex(where: { $0.id == memo.id }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    memos[rollbackIndex] = original
                }
            }
            self.errorMessage = "우선순위 변경 실패: \(error.localizedDescription)"
        }
    }

    public func updateMemo(_ memo: MemoItem) async {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        let original = memos[index]
        self.memos[index] = memo

        do {
            try await environment.manageMemoUseCase.updateMemo(memo)
        } catch {
            if let rollbackIndex = memos.firstIndex(where: { $0.id == memo.id }) {
                memos[rollbackIndex] = original
            }
            self.errorMessage = "메모 수정 실패: \(error.localizedDescription)"
        }
    }

    public func deleteMemo(id: UUID) async -> Int {
        do {
            try await environment.manageMemoUseCase.deleteMemo(id: id)
            memos.removeAll { $0.id == id }
            return memos.count
        } catch {
            self.errorMessage = "메모 삭제 실패: \(error.localizedDescription)"
            return memos.count
        }
    }

    public func fetchLatestCommitIfNeeded(for repo: RepositoryItem) async {
        // 이미 커밋 메시지가 있으면 스킵
        if repository?.lastCommitMessage != nil { return }

        let settings = environment.settingsRepository.loadSettings()
        guard !settings.githubToken.isEmpty else { return }

        isLoadingCommit = true
        if let result = try? await environment.githubRepository.fetchLatestCommit(
            token: settings.githubToken,
            owner: repo.owner,
            repo: repo.name,
            branch: repo.defaultBranch
        ) {
            if self.repository?.id == repo.id {
                self.repository?.lastCommitDate = result.date
                self.repository?.lastCommitMessage = result.message
            }
        }
        isLoadingCommit = false
    }

    public var staleStatus: StaleStatus {
        guard let repo = repository else { return .unknown }
        let settings = environment.settingsRepository.loadSettings()
        return environment.calculateStaleStatusUseCase.execute(
            latestDate: repo.latestActivityDate,
            warningThreshold: settings.warningThresholdDays,
            staleThreshold: settings.staleThresholdDays
        )
    }

    // MARK: - Local Folder Management
    public func setLocalDirectoryPath(_ path: String) {
        guard let repo = repository else { return }
        self.localDirectoryPath = path
        environment.localPathRepository.setLocalPath(path, for: repo.id)
        if let session = environment.terminalSessionManager.session(for: repo.id) {
            session.updateWorkingDirectoryIfNeeded(path)
        }
    }

    public func chooseLocalFolder() {
        guard let repo = repository else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "선택"
        panel.message = "[\(repo.name)]의 로컬 프로젝트 폴더를 선택해 주세요."

        if panel.runModal() == .OK, let url = panel.url {
            setLocalDirectoryPath(url.path)
        }
    }

    public func openInVSCode() {
        guard let path = localDirectoryPath else {
            chooseLocalFolder()
            guard let newPath = localDirectoryPath else { return }
            openPath(newPath, appName: "Visual Studio Code")
            return
        }
        openPath(path, appName: "Visual Studio Code")
    }

    public func openInCursor() {
        guard let path = localDirectoryPath else {
            chooseLocalFolder()
            guard let newPath = localDirectoryPath else { return }
            openPath(newPath, appName: "Cursor")
            return
        }
        openPath(path, appName: "Cursor")
    }

    public func openInFinder() {
        guard let path = localDirectoryPath else {
            chooseLocalFolder()
            guard let newPath = localDirectoryPath else { return }
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: newPath)
            return
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    private func openPath(_ path: String, appName: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", appName, path]
        do {
            try task.run()
            self.successMessage = "[\(appName)]에서 프로젝트 폴더를 열었습니다."
        } catch {
            self.errorMessage = "\(appName) 실행 실패: \(error.localizedDescription)"
        }
    }

    // MARK: - AI Guideline Management
    public func openGuidelineSettings() {
        if localDirectoryPath == nil || !FileManager.default.fileExists(atPath: localDirectoryPath!) {
            chooseLocalFolder()
        }
        guard let path = localDirectoryPath, FileManager.default.fileExists(atPath: path) else {
            self.errorMessage = "지침을 설정할 로컬 폴더를 먼저 지정해 주세요."
            return
        }
        guidelineSelectedPreset = environment.settingsRepository.loadSettings().aiAgentPreset
        loadGuideline(for: guidelineSelectedPreset, localPath: path)
        isGuidelineSheetPresented = true
    }

    public func selectGuidelinePreset(_ preset: AppSettings.AIAgentPreset) {
        guard let path = localDirectoryPath else { return }
        guidelineSelectedPreset = preset
        loadGuideline(for: preset, localPath: path)
    }

    private func loadGuideline(for preset: AppSettings.AIAgentPreset, localPath: String) {
        guidelineContent = environment.manageRepositoryGuidelineUseCase.loadGuideline(localPath: localPath, preset: preset) ?? ""
    }

    public func guidelineFilePath(for preset: AppSettings.AIAgentPreset) -> String? {
        guard let path = localDirectoryPath else { return nil }
        return environment.manageRepositoryGuidelineUseCase.filePath(localPath: path, preset: preset)
    }

    public func guidelineExists(for preset: AppSettings.AIAgentPreset) -> Bool {
        guard let path = localDirectoryPath else { return false }
        return environment.manageRepositoryGuidelineUseCase.guidelineExists(localPath: path, preset: preset)
    }

    public func saveGuideline() {
        guard let path = localDirectoryPath else {
            self.errorMessage = "지침을 저장할 로컬 폴더를 먼저 지정해 주세요."
            return
        }
        do {
            try environment.manageRepositoryGuidelineUseCase.saveGuideline(
                localPath: path,
                preset: guidelineSelectedPreset,
                content: guidelineContent
            )
            self.successMessage = "[\(guidelineSelectedPreset.shortName)] 지침이 저장되었습니다."
        } catch {
            self.errorMessage = "지침 저장 실패: \(error.localizedDescription)"
        }
    }

    // MARK: - AI Agent Task Execution
    public var defaultAIPreset: AppSettings.AIAgentPreset {
        environment.settingsRepository.loadSettings().aiAgentPreset
    }

    public func executeTask(for memo: MemoItem, preset: AppSettings.AIAgentPreset? = nil) async {
        guard let repo = repository else { return }

        // 로컬 경로 확인 (없으면 폴더 선택기 열기)
        var targetPath = localDirectoryPath
        if targetPath == nil || !FileManager.default.fileExists(atPath: targetPath!) {
            chooseLocalFolder()
            targetPath = localDirectoryPath
        }

        guard let validPath = targetPath, FileManager.default.fileExists(atPath: validPath) else {
            self.errorMessage = "작업을 실행할 로컬 폴더를 먼저 지정해 주세요."
            return
        }

        isExecutingTask = true
        errorMessage = nil

        let settings = environment.settingsRepository.loadSettings()
        let activePreset = preset ?? settings.aiAgentPreset

        do {
            let prompt = environment.executeAgentTaskUseCase.buildPrompt(repository: repo, memo: memo, template: settings.customPromptTemplate)
            let command = environment.executeAgentTaskUseCase.buildCommand(prompt: prompt, settings: settings, overridePreset: preset)

            environment.terminalSessionManager.executeCommand(
                command: command,
                repositoryId: repo.id,
                name: repo.name,
                localPath: validPath,
                preset: activePreset,
                profile: settings.terminalApp
            )

            var updatedMemo = memo
            updatedMemo.status = .inProgress
            updatedMemo.lastExecutedAt = Date()
            updatedMemo.updatedAt = Date()
            try await environment.memoRepository.saveMemo(updatedMemo)

            if let index = memos.firstIndex(where: { $0.id == memo.id }) {
                memos[index] = updatedMemo
            }
            self.successMessage = "내장 터미널에서 [\(activePreset.shortName)] 작업을 시작했습니다!"
        } catch {
            self.errorMessage = "작업 실행 실패: \(error.localizedDescription)"
        }

        isExecutingTask = false
    }

    // MARK: - Memo Selection Management
    public var selectedMemos: [MemoItem] {
        memos.filter { selectedMemoIds.contains($0.id) }
    }

    public func toggleMemoSelection(id: UUID) {
        if selectedMemoIds.contains(id) {
            selectedMemoIds.remove(id)
        } else {
            selectedMemoIds.insert(id)
        }
    }

    public func selectAll(ids: [UUID]) {
        selectedMemoIds = Set(ids)
    }

    public func clearSelection() {
        selectedMemoIds.removeAll()
    }

    // MARK: - Batch AI Agent Task Execution
    public func executeBatchTask(preset: AppSettings.AIAgentPreset? = nil) async {
        guard let repo = repository else { return }
        let targets = selectedMemos
        guard !targets.isEmpty else {
            self.errorMessage = "작업할 메모를 먼저 선택해 주세요."
            return
        }

        // 로컬 경로 확인 (없으면 폴더 선택기 열기)
        var targetPath = localDirectoryPath
        if targetPath == nil || !FileManager.default.fileExists(atPath: targetPath!) {
            chooseLocalFolder()
            targetPath = localDirectoryPath
        }

        guard let validPath = targetPath, FileManager.default.fileExists(atPath: validPath) else {
            self.errorMessage = "작업을 실행할 로컬 폴더를 먼저 지정해 주세요."
            return
        }

        isExecutingTask = true
        errorMessage = nil

        let settings = environment.settingsRepository.loadSettings()
        let activePreset = preset ?? settings.aiAgentPreset

        do {
            let prompt = environment.executeAgentTaskUseCase.buildBatchPrompt(repository: repo, memos: targets, template: settings.customPromptTemplate)
            let command = environment.executeAgentTaskUseCase.buildCommand(prompt: prompt, settings: settings, overridePreset: preset)

            environment.terminalSessionManager.executeCommand(
                command: command,
                repositoryId: repo.id,
                name: repo.name,
                localPath: validPath,
                preset: activePreset,
                profile: settings.terminalApp
            )

            let now = Date()
            for var memo in targets {
                memo.status = .inProgress
                memo.lastExecutedAt = now
                memo.updatedAt = now
                try await environment.memoRepository.saveMemo(memo)
                if let index = memos.firstIndex(where: { $0.id == memo.id }) {
                    memos[index] = memo
                }
            }

            self.successMessage = "내장 터미널에서 선택한 \(targets.count)개 항목에 대해 [\(activePreset.shortName)] 작업을 시작했습니다!"
            self.selectedMemoIds.removeAll()
        } catch {
            self.errorMessage = "일괄 작업 실행 실패: \(error.localizedDescription)"
        }

        isExecutingTask = false
    }

    public func copyBatchPrompt() {
        guard let repo = repository else { return }
        let targets = selectedMemos
        guard !targets.isEmpty else { return }

        let settings = environment.settingsRepository.loadSettings()
        let prompt = environment.executeAgentTaskUseCase.buildBatchPrompt(
            repository: repo,
            memos: targets,
            template: settings.customPromptTemplate
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        self.successMessage = "선택한 \(targets.count)개 항목의 AI 통합 프롬프트가 복사되었습니다."
    }

    public func batchToggleCompletion() async {
        let targets = selectedMemos
        guard !targets.isEmpty else { return }

        // 모두 완료 상태이면 미완료로, 하나라도 미완료가 있으면 완료로 변경
        let allCompleted = targets.allSatisfy { $0.isCompleted }
        let newCompletionState = !allCompleted
        let now = Date()

        // 1. 낙관적 UI 즉시 반영
        for target in targets {
            if let index = memos.firstIndex(where: { $0.id == target.id }) {
                memos[index].isCompleted = newCompletionState
                memos[index].updatedAt = now
            }
        }
        self.selectedMemoIds.removeAll()

        // 2. 백그라운드 영속화
        for target in targets {
            var updated = target
            updated.isCompleted = newCompletionState
            updated.updatedAt = now
            try? await environment.manageMemoUseCase.updateMemo(updated)
        }
        self.successMessage = "선택한 \(targets.count)개 항목을 \(newCompletionState ? "완료" : "대기 중") 상태로 변경했습니다."
    }

    public func batchUpdateStatus(_ newStatus: MemoItem.Status) async {
        let targets = selectedMemos
        guard !targets.isEmpty else { return }
        let now = Date()

        // 1. 낙관적 UI 즉시 반영
        for target in targets {
            if let index = memos.firstIndex(where: { $0.id == target.id }) {
                memos[index].status = newStatus
                memos[index].updatedAt = now
            }
        }
        self.selectedMemoIds.removeAll()

        // 2. 백그라운드 영속화
        for target in targets {
            var updated = target
            updated.status = newStatus
            updated.updatedAt = now
            try? await environment.manageMemoUseCase.updateMemo(updated)
        }
        self.successMessage = "선택한 \(targets.count)개 항목의 상태를 '\(newStatus.rawValue)'으로 변경했습니다."
    }

    public func batchDeleteSelectedMemos() async -> Int {
        let targets = selectedMemos
        guard !targets.isEmpty else { return memos.count }

        let targetIds = Set(targets.map { $0.id })
        self.memos.removeAll { targetIds.contains($0.id) }
        self.selectedMemoIds.removeAll()

        for id in targetIds {
            try? await environment.manageMemoUseCase.deleteMemo(id: id)
        }
        self.successMessage = "\(targetIds.count)개 메모를 삭제했습니다."
        return self.memos.count
    }

    public func copyPrompt(for memo: MemoItem) {
        guard let repo = repository else { return }
        let settings = environment.settingsRepository.loadSettings()
        let prompt = environment.executeAgentTaskUseCase.buildPrompt(
            repository: repo,
            memo: memo,
            template: settings.customPromptTemplate
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        self.successMessage = "AI 프롬프트가 클립보드에 복사되었습니다."
    }
}
