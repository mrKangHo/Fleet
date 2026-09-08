import Foundation

/// GitHub 저장소 생성/삭제와 그에 따른 로컬 상태(모니터링 설정, 로컬 경로, 메모) 정리를 담당하는 Use Case
public struct ManageRepositoryUseCase: Sendable {
    private let githubRepository: GitHubRepositoryProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    private let localPathRepository: LocalPathRepositoryProtocol
    private let memoRepository: MemoRepositoryProtocol

    public init(
        githubRepository: GitHubRepositoryProtocol,
        settingsRepository: SettingsRepositoryProtocol,
        localPathRepository: LocalPathRepositoryProtocol,
        memoRepository: MemoRepositoryProtocol
    ) {
        self.githubRepository = githubRepository
        self.settingsRepository = settingsRepository
        self.localPathRepository = localPathRepository
        self.memoRepository = memoRepository
    }

    /// GitHub에 새 저장소를 생성하고, 생성된 저장소를 모니터링 대상으로 등록합니다.
    @discardableResult
    public func createRepository(
        token: String,
        name: String,
        description: String?,
        isPrivate: Bool,
        settings: AppSettings
    ) async throws -> RepositoryItem {
        let repo = try await githubRepository.createRepository(
            token: token,
            name: name,
            description: description,
            isPrivate: isPrivate
        )

        var updatedSettings = settings
        if updatedSettings.monitoredRepoIds != nil {
            updatedSettings.monitoredRepoIds?.insert(repo.id)
        }
        updatedSettings.ignoredRepoIds.remove(repo.id)
        updatedSettings.hasCompletedInitialSelection = true
        settingsRepository.saveSettings(updatedSettings)

        return repo
    }

    /// GitHub에서 저장소를 삭제하고, 관련된 로컬 모니터링 설정/로컬 경로/메모를 정리합니다.
    public func deleteRepository(_ repo: RepositoryItem, settings: AppSettings) async throws {
        try await githubRepository.deleteRepository(token: settings.githubToken, owner: repo.owner, repo: repo.name)

        var updatedSettings = settings
        updatedSettings.monitoredRepoIds?.remove(repo.id)
        updatedSettings.ignoredRepoIds.remove(repo.id)
        settingsRepository.saveSettings(updatedSettings)

        localPathRepository.removeLocalPath(for: repo.id)

        let memos = try await memoRepository.getMemos(for: repo.id)
        for memo in memos {
            try await memoRepository.deleteMemo(id: memo.id)
        }
    }
}
