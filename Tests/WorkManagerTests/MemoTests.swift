import XCTest
@testable import WorkManager

final class MockMemoRepository: MemoRepositoryProtocol, @unchecked Sendable {
    private var memos: [UUID: MemoItem] = [:]

    func getMemos(for repositoryId: Int) async throws -> [MemoItem] {
        memos.values.filter { $0.repositoryId == repositoryId }
    }

    func getAllMemos() async throws -> [MemoItem] {
        Array(memos.values)
    }

    func saveMemo(_ memo: MemoItem) async throws {
        memos[memo.id] = memo
    }

    func deleteMemo(id: UUID) async throws {
        memos.removeValue(forKey: id)
    }

    func getMemoCount(for repositoryId: Int) async throws -> Int {
        memos.values.filter { $0.repositoryId == repositoryId }.count
    }

    func getMemoCounts() async throws -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for item in memos.values {
            counts[item.repositoryId, default: 0] += 1
        }
        return counts
    }
}

final class ManageMemoUseCaseTests: XCTestCase {
    private var repository: MockMemoRepository!
    private var useCase: ManageMemoUseCase!

    override func setUp() {
        super.setUp()
        repository = MockMemoRepository()
        useCase = ManageMemoUseCase(memoRepository: repository)
    }

    func testAddAndFetchMemos() async throws {
        let memo = try await useCase.addMemo(
            repositoryId: 101,
            title: "OAuth 로그인 추가",
            content: "Apple & Google 로그인",
            priority: .high
        )

        XCTAssertEqual(memo.title, "OAuth 로그인 추가")
        XCTAssertEqual(memo.priority, .high)
        XCTAssertFalse(memo.isCompleted)

        let list = try await useCase.getMemos(for: 101)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.title, "OAuth 로그인 추가")
    }

    func testToggleCompletion() async throws {
        let memo = try await useCase.addMemo(
            repositoryId: 102,
            title: "다크모드 지원"
        )
        XCTAssertFalse(memo.isCompleted)

        let updated = try await useCase.toggleCompletion(for: memo)
        XCTAssertTrue(updated.isCompleted)

        let list = try await useCase.getMemos(for: 102)
        XCTAssertTrue(list.first?.isCompleted == true)
    }

    func testDeleteMemo() async throws {
        let memo = try await useCase.addMemo(
            repositoryId: 103,
            title: "삭제 테스트"
        )

        try await useCase.deleteMemo(id: memo.id)
        let list = try await useCase.getMemos(for: 103)
        XCTAssertTrue(list.isEmpty)
    }
}
