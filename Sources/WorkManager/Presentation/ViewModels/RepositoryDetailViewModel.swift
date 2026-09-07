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
        do {
            let updated = try await environment.manageMemoUseCase.toggleCompletion(for: memo)
            if let index = memos.firstIndex(where: { $0.id == memo.id }) {
                memos[index] = updated
            }
        } catch {
            self.errorMessage = "상태 변경 실패: \(error.localizedDescription)"
        }
    }

    public func updateMemo(_ memo: MemoItem) async {
        do {
            try await environment.manageMemoUseCase.updateMemo(memo)
            if let index = memos.firstIndex(where: { $0.id == memo.id }) {
                memos[index] = memo
            }
        } catch {
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
            if settings.terminalApp == .embedded {
                let prompt = environment.executeAgentTaskUseCase.buildPrompt(repository: repo, memo: memo, template: settings.customPromptTemplate)
                let command = environment.executeAgentTaskUseCase.buildCommand(prompt: prompt, settings: settings, overridePreset: preset)

                environment.terminalSessionManager.executeCommand(
                    command: command,
                    repositoryId: repo.id,
                    name: repo.name,
                    localPath: validPath,
                    preset: activePreset
                )

                var updatedMemo = memo
                updatedMemo.status = .inProgress
                updatedMemo.lastExecutedAt = Date()
                updatedMemo.updatedAt = Date()
                try await environment.memoRepository.saveMemo(updatedMemo)

                if let index = memos.firstIndex(where: { $0.id == memo.id }) {
                    memos[index] = updatedMemo
                }
                self.successMessage = "하단 터미널에서 [\(activePreset.shortName)] 작업을 시작했습니다!"
            } else {
                let updated = try await environment.executeAgentTaskUseCase.execute(
                    repository: repo,
                    memo: memo,
                    localPath: validPath,
                    settings: settings,
                    overridePreset: preset
                )

                if let index = memos.firstIndex(where: { $0.id == memo.id }) {
                    memos[index] = updated
                }
                self.successMessage = "터미널에서 [\(activePreset.shortName)] 작업을 시작했습니다!"
            }
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
            if settings.terminalApp == .embedded {
                let prompt = environment.executeAgentTaskUseCase.buildBatchPrompt(repository: repo, memos: targets, template: settings.customPromptTemplate)
                let command = environment.executeAgentTaskUseCase.buildCommand(prompt: prompt, settings: settings, overridePreset: preset)

                environment.terminalSessionManager.executeCommand(
                    command: command,
                    repositoryId: repo.id,
                    name: repo.name,
                    localPath: validPath,
                    preset: activePreset
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

                self.successMessage = "하단 터미널에서 선택한 \(targets.count)개 항목에 대해 [\(activePreset.shortName)] 작업을 시작했습니다!"
            } else {
                let updatedList = try await environment.executeAgentTaskUseCase.executeBatch(
                    repository: repo,
                    memos: targets,
                    localPath: validPath,
                    settings: settings,
                    overridePreset: preset
                )

                // 로컬 메모 리스트 갱신
                for updated in updatedList {
                    if let index = memos.firstIndex(where: { $0.id == updated.id }) {
                        memos[index] = updated
                    }
                }

                self.successMessage = "터미널에서 선택한 \(targets.count)개 항목에 대해 [\(activePreset.shortName)] 작업을 시작했습니다!"
            }
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

        for target in targets {
            var updated = target
            updated.isCompleted = newCompletionState
            updated.updatedAt = Date()
            await updateMemo(updated)
        }
        self.selectedMemoIds.removeAll()
        self.successMessage = "\(targets.count)개 항목의 완료 상태가 변경되었습니다."
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
