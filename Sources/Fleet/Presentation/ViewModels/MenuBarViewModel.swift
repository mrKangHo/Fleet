import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
    private let environment: AppEnvironment

    @Published public var repositories: [RepositoryItem] = []
    @Published public var memos: [MemoItem] = []
    @Published public var selectedRepoId: Int? = nil
    @Published public var quickTaskText: String = ""
    @Published public var isLoading: Bool = false
    @Published public var settings: AppSettings = .default

    public init(environment: AppEnvironment = .shared) {
        self.environment = environment
        self.settings = environment.settingsRepository.loadSettings()
    }

    public var staleRepos: [RepositoryItem] {
        repositories.filter { repo in
            let status = environment.calculateStaleStatusUseCase.execute(
                latestDate: repo.lastCommitDate,
                warningThreshold: settings.staleThresholdDays,
                staleThreshold: settings.criticalThresholdDays
            )
            return status.isStale || status.isWarning
        }
    }

    public var displayRepos: [RepositoryItem] {
        let stale = staleRepos
        return stale.isEmpty ? Array(repositories.prefix(4)) : stale
    }

    public var selectedRepoName: String {
        if let id = selectedRepoId, let repo = repositories.first(where: { $0.id == id }) {
            return repo.name
        }
        return repositories.first?.name ?? "선택"
    }

    public func staleStatus(for repo: RepositoryItem) -> StaleStatus {
        environment.calculateStaleStatusUseCase.execute(
            latestDate: repo.lastCommitDate,
            warningThreshold: settings.staleThresholdDays,
            staleThreshold: settings.criticalThresholdDays
        )
    }

    public func selectRepo(_ id: Int) {
        selectedRepoId = id
    }

    public func loadData() async {
        isLoading = true
        defer { isLoading = false }

        settings = environment.settingsRepository.loadSettings()

        if let fetched = try? await environment.fetchRepositoriesUseCase.execute(token: settings.githubToken, settings: settings) {
            repositories = fetched
            if selectedRepoId == nil {
                selectedRepoId = fetched.first?.id
            }
        }

        if let targetId = selectedRepoId ?? repositories.first?.id {
            if let fetchedMemos = try? await environment.manageMemoUseCase.getMemos(for: targetId) {
                memos = fetchedMemos
            }
        }
    }

    public func submitQuickTask() {
        let trimmed = quickTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let targetId = selectedRepoId ?? repositories.first?.id else { return }

        Task {
            _ = try? await environment.manageMemoUseCase.addMemo(
                repositoryId: targetId,
                title: trimmed,
                content: "",
                priority: .medium
            )
            quickTaskText = ""
            await loadData()
        }
    }

    public func toggleCompletion(for memo: MemoItem) async {
        _ = try? await environment.manageMemoUseCase.toggleCompletion(for: memo)
        await loadData()
    }
}
