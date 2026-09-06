import Foundation

/// GitHub 저장소 도메인 엔티티
public struct RepositoryItem: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let owner: String
    public let ownerAvatarUrl: String?
    public let isPrivate: Bool
    public let isFork: Bool
    public let isArchived: Bool
    public let htmlUrl: URL
    public let description: String?
    public let defaultBranch: String
    public let language: String?
    public let stargazersCount: Int
    public let forksCount: Int
    public let openIssuesCount: Int
    public let pushedAt: Date?
    public var lastCommitDate: Date?
    public var lastCommitMessage: String?
    public var memoCount: Int

    public init(
        id: Int,
        name: String,
        fullName: String,
        owner: String,
        ownerAvatarUrl: String? = nil,
        isPrivate: Bool = false,
        isFork: Bool = false,
        isArchived: Bool = false,
        htmlUrl: URL,
        description: String? = nil,
        defaultBranch: String = "main",
        language: String? = nil,
        stargazersCount: Int = 0,
        forksCount: Int = 0,
        openIssuesCount: Int = 0,
        pushedAt: Date? = nil,
        lastCommitDate: Date? = nil,
        lastCommitMessage: String? = nil,
        memoCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.owner = owner
        self.ownerAvatarUrl = ownerAvatarUrl
        self.isPrivate = isPrivate
        self.isFork = isFork
        self.isArchived = isArchived
        self.htmlUrl = htmlUrl
        self.description = description
        self.defaultBranch = defaultBranch
        self.language = language
        self.stargazersCount = stargazersCount
        self.forksCount = forksCount
        self.openIssuesCount = openIssuesCount
        self.pushedAt = pushedAt
        self.lastCommitDate = lastCommitDate ?? pushedAt
        self.lastCommitMessage = lastCommitMessage
        self.memoCount = memoCount
    }

    /// 마지막 활동 날짜 (커밋 날짜 우선, 없을 시 푸시 날짜)
    public var latestActivityDate: Date? {
        lastCommitDate ?? pushedAt
    }
}
