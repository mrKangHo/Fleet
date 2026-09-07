import Foundation

/// GitHub 저장소를 불러오고 메모 정보 및 설정을 반영하는 Use Case
public struct FetchRepositoriesUseCase: Sendable {
    private let githubRepository: GitHubRepositoryProtocol
    private let memoRepository: MemoRepositoryProtocol

    public init(
        githubRepository: GitHubRepositoryProtocol,
        memoRepository: MemoRepositoryProtocol
    ) {
        self.githubRepository = githubRepository
        self.memoRepository = memoRepository
    }

    public func execute(token: String, settings: AppSettings) async throws -> [RepositoryItem] {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        // 1. GitHub에서 저장소 목록 조회
        var repos = try await githubRepository.fetchRepositories(token: token)

        // 2. 설정에 따른 필터링 (Archived, Fork 제외 옵션)
        if settings.excludeArchived {
            repos = repos.filter { !$0.isArchived }
        }
        if settings.excludeForks {
            repos = repos.filter { !$0.isFork }
        }

        // 3. 로컬 메모 카운트 매핑
        let memoCounts = try await memoRepository.getMemoCounts()
        repos = repos.map { repo in
            var updated = repo
            updated.memoCount = memoCounts[repo.id] ?? 0
            return updated
        }

        return repos
    }
}
