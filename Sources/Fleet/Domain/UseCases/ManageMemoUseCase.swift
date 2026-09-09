import Foundation

/// 저장소별 업데이트 메모를 관리하는 Use Case
public struct ManageMemoUseCase: Sendable {
    private let memoRepository: MemoRepositoryProtocol

    public init(memoRepository: MemoRepositoryProtocol) {
        self.memoRepository = memoRepository
    }

    /// 특정 저장소의 모든 메모 조회 (생성일 역순)
    public func getMemos(for repositoryId: Int) async throws -> [MemoItem] {
        let memos = try await memoRepository.getMemos(for: repositoryId)
        return memos.sorted { $0.createdAt > $1.createdAt }
    }

    /// 모든 저장소에 걸친 전체 메모 조회 (생성일 역순)
    public func getAllMemos() async throws -> [MemoItem] {
        let memos = try await memoRepository.getAllMemos()
        return memos.sorted { $0.createdAt > $1.createdAt }
    }

    /// 신규 메모 추가
    @discardableResult
    public func addMemo(
        repositoryId: Int,
        title: String,
        content: String = "",
        priority: MemoItem.Priority = .medium
    ) async throws -> MemoItem {
        let newMemo = MemoItem(
            repositoryId: repositoryId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: false,
            priority: priority,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await memoRepository.saveMemo(newMemo)
        return newMemo
    }

    /// 메모 완료 여부 토글
    public func toggleCompletion(for memo: MemoItem) async throws -> MemoItem {
        var updated = memo
        updated.isCompleted.toggle()
        updated.updatedAt = Date()
        try await memoRepository.saveMemo(updated)
        return updated
    }

    /// 메모 내용 수정
    public func updateMemo(_ memo: MemoItem) async throws {
        var updated = memo
        updated.updatedAt = Date()
        try await memoRepository.saveMemo(updated)
    }

    /// 메모 삭제
    public func deleteMemo(id: UUID) async throws {
        try await memoRepository.deleteMemo(id: id)
    }
}
