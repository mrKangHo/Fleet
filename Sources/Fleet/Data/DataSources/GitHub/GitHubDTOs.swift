import Foundation

// MARK: - GitHub User DTO
public struct GitHubUserDTO: Codable, Sendable {
    public let login: String
    public let id: Int
    public let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
    }
}

// MARK: - GitHub Repository DTO
public struct GitHubRepoDTO: Codable, Sendable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let owner: GitHubUserDTO
    public let `private`: Bool
    public let fork: Bool
    public let archived: Bool?
    public let htmlUrl: String
    public let description: String?
    public let defaultBranch: String?
    public let language: String?
    public let stargazersCount: Int?
    public let forksCount: Int?
    public let openIssuesCount: Int?
    public let pushedAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, owner, fork, archived, description, language
        case fullName = "full_name"
        case `private` = "private"
        case htmlUrl = "html_url"
        case defaultBranch = "default_branch"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case pushedAt = "pushed_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - GitHub Error DTO
public struct GitHubErrorDTO: Codable, Sendable {
    public let message: String
}

// MARK: - GitHub Commit DTO
public struct GitHubCommitResponseDTO: Codable, Sendable {
    public let sha: String
    public let commit: InnerCommitDTO

    public struct InnerCommitDTO: Codable, Sendable {
        public let message: String
        public let committer: CommitterDTO?
        public let author: CommitterDTO?
    }

    public struct CommitterDTO: Codable, Sendable {
        public let name: String?
        public let date: String?
    }
}
