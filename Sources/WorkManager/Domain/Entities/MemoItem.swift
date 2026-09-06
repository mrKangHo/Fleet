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
}
