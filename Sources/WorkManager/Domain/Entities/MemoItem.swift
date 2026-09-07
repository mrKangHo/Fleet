import Foundation

/// 저장소별 업데이트할 기능 및 아이디어 메모 엔티티
public struct MemoItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let repositoryId: Int
    public var title: String
    public var content: String
    public var priority: Priority
    public let createdAt: Date
    public var updatedAt: Date

    public enum Priority: String, Codable, CaseIterable, Sendable {
        case low = "낮음"
        case medium = "보통"
        case high = "높음"
    }

    public enum Status: String, Codable, CaseIterable, Sendable {
        case pending = "대기 중"
        case inProgress = "작업 중 🚀"
        case completed = "완료됨"
    }

    public var isCompleted: Bool {
        get { status == .completed }
        set { status = newValue ? .completed : .pending }
    }

    public var status: Status
    public var lastExecutedAt: Date?

    public init(
        id: UUID = UUID(),
        repositoryId: Int,
        title: String,
        content: String = "",
        status: Status = .pending,
        priority: Priority = .medium,
        lastExecutedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.repositoryId = repositoryId
        self.title = title
        self.content = content
        self.status = status
        self.priority = priority
        self.lastExecutedAt = lastExecutedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 하위 호환 이니셜라이저
    public init(
        id: UUID = UUID(),
        repositoryId: Int,
        title: String,
        content: String = "",
        isCompleted: Bool,
        priority: Priority = .medium,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.repositoryId = repositoryId
        self.title = title
        self.content = content
        self.status = isCompleted ? .completed : .pending
        self.priority = priority
        self.lastExecutedAt = nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Codable (하위 호환 및 누락 필드 방어)
    enum CodingKeys: String, CodingKey {
        case id, repositoryId, title, content, priority, status, isCompleted, lastExecutedAt, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        repositoryId = try container.decode(Int.self, forKey: .repositoryId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        priority = try container.decodeIfPresent(Priority.self, forKey: .priority) ?? .medium
        lastExecutedAt = try container.decodeIfPresent(Date.self, forKey: .lastExecutedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        if let decodedStatus = try container.decodeIfPresent(Status.self, forKey: .status) {
            status = decodedStatus
        } else if let legacyCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) {
            status = legacyCompleted ? .completed : .pending
        } else {
            status = .pending
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(repositoryId, forKey: .repositoryId)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(priority, forKey: .priority)
        try container.encode(status, forKey: .status)
        try container.encode(lastExecutedAt, forKey: .lastExecutedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
