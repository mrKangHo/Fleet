import Foundation

/// 저장소별 메모 데이터 접근 프로토콜 (Domain Layer 인터페이스)
public protocol MemoRepositoryProtocol: Sendable {
    /// 특정 저장소에 등록된 모든 메모를 가져옵니다.
    func getMemos(for repositoryId: Int) async throws -> [MemoItem]
    
    /// 모든 메모 목록을 가져옵니다.
    func getAllMemos() async throws -> [MemoItem]
    
    /// 메모를 저장하거나 수정합니다.
    func saveMemo(_ memo: MemoItem) async throws
    
    /// 메모를 삭제합니다.
    func deleteMemo(id: UUID) async throws
    
    /// 특정 저장소의 메모 개수를 가져옵니다.
    func getMemoCount(for repositoryId: Int) async throws -> Int
    
    /// 저장소 ID 목록에 대한 각 메모 개수 맵(Dictionary)을 가져옵니다.
    func getMemoCounts() async throws -> [Int: Int]
}
