import XCTest
@testable import Fleet

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

    func testLegacyMemoJsonDecoding() throws {
        // 과거 버전의 JSON (status 없이 isCompleted만 있는 경우)
        let legacyJson = """
        {
            "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "repositoryId": 999,
            "title": "레거시 메모",
            "content": "이전 버전에서 작성됨",
            "isCompleted": true,
            "priority": "높음",
            "createdAt": 1700000000,
            "updatedAt": 1700000000
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MemoItem.self, from: legacyJson)
        XCTAssertEqual(decoded.title, "레거시 메모")
        XCTAssertEqual(decoded.status, .completed)
        XCTAssertTrue(decoded.isCompleted)
        XCTAssertEqual(decoded.priority, .high)
    }

    func testStatusTransitionsAndIsCompleted() {
        var memo = MemoItem(repositoryId: 200, title: "상태 전환 테스트")
        XCTAssertEqual(memo.status, .pending)
        XCTAssertFalse(memo.isCompleted)

        // 작업 중 🚀 으로 전환
        memo.status = .inProgress
        XCTAssertEqual(memo.status, .inProgress)
        XCTAssertFalse(memo.isCompleted)

        // 완료 처리
        memo.isCompleted = true
        XCTAssertEqual(memo.status, .completed)
        XCTAssertTrue(memo.isCompleted)

        // 완료 해제 -> 대기 중으로 복귀
        memo.isCompleted = false
        XCTAssertEqual(memo.status, .pending)
        XCTAssertFalse(memo.isCompleted)
    }

    func testCustomMemoItemEncodingAndDecoding() throws {
        let original = MemoItem(
            repositoryId: 300,
            title: "인코딩 라운드트립",
            content: "세부 내용",
            status: .inProgress,
            priority: .high
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MemoItem.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.repositoryId, original.repositoryId)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.status, .inProgress)
        XCTAssertEqual(decoded.priority, .high)
        XCTAssertFalse(decoded.isCompleted)
    }
}
