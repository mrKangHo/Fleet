import Foundation

/// GitHubRepositoryProtocol 구현체
public final class GitHubRepositoryImpl: GitHubRepositoryProtocol, Sendable {
    private let apiService: GitHubAPIService

    public init(apiService: GitHubAPIService = GitHubAPIService()) {
        self.apiService = apiService
    }

    public func validateToken(token: String) async throws -> String {
        try await apiService.validateToken(token: token)
    }

    public func validateTokenWithScopes(token: String) async throws -> (username: String, hasRepoScope: Bool) {
        try await apiService.validateTokenWithScopes(token: token)
    }

    public func fetchRepositories(token: String) async throws -> [RepositoryItem] {
        let repoDTOs = try await apiService.fetchUserRepositories(token: token)

        return repoDTOs.map { dto in
            let date = parseDate(dto.pushedAt) ?? parseDate(dto.updatedAt)
            return RepositoryItem(
                id: dto.id,
                name: dto.name,
                fullName: dto.fullName,
                owner: dto.owner.login,
                ownerAvatarUrl: dto.owner.avatarUrl,
                isPrivate: dto.private,
                isFork: dto.fork,
                isArchived: dto.archived ?? false,
                htmlUrl: URL(string: dto.htmlUrl) ?? URL(string: "https://github.com/\(dto.fullName)")!,
                description: dto.description,
                defaultBranch: dto.defaultBranch ?? "main",
                language: dto.language,
                stargazersCount: dto.stargazersCount ?? 0,
                forksCount: dto.forksCount ?? 0,
                openIssuesCount: dto.openIssuesCount ?? 0,
                pushedAt: date,
                lastCommitDate: date,
                lastCommitMessage: nil,
                memoCount: 0
            )
        }
    }

    public func fetchLatestCommit(
        token: String,
        owner: String,
        repo: String,
        branch: String
    ) async throws -> (date: Date, message: String)? {
        try await apiService.fetchLatestCommit(token: token, owner: owner, repo: repo, branch: branch)
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractionalFormatter.date(from: string)
    }
}
