import Foundation

/// MemoRepositoryProtocol 구현체 (LocalMemoStorage 연동)
public final class MemoRepositoryImpl: MemoRepositoryProtocol, Sendable {
    private let storage: LocalMemoStorage

    public init(storage: LocalMemoStorage = LocalMemoStorage()) {
        self.storage = storage
    }

    public func getMemos(for repositoryId: Int) async throws -> [MemoItem] {
        await storage.getMemos(for: repositoryId)
    }

    public func getAllMemos() async throws -> [MemoItem] {
        await storage.getAllMemos()
    }

    public func saveMemo(_ memo: MemoItem) async throws {
        try await storage.saveMemo(memo)
    }

    public func deleteMemo(id: UUID) async throws {
        try await storage.deleteMemo(id: id)
    }

    public func getMemoCount(for repositoryId: Int) async throws -> Int {
        await storage.getMemoCount(for: repositoryId)
    }

    public func getMemoCounts() async throws -> [Int: Int] {
        await storage.getMemoCounts()
    }
}
