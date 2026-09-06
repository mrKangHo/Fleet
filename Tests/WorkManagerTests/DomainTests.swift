import XCTest
@testable import WorkManager

final class CalculateStaleStatusUseCaseTests: XCTestCase {
    private var useCase: CalculateStaleStatusUseCase!
    private let calendar = Calendar.current

    override func setUp() {
        super.setUp()
        useCase = CalculateStaleStatusUseCase(calendar: calendar)
    }

    func testTodayActivityIsActive() {
        let now = Date()
        let status = useCase.execute(
            latestDate: now,
            currentDate: now,
            warningThreshold: 14,
            staleThreshold: 30
        )

        XCTAssertEqual(status.elapsedDays, 0)
        XCTAssertEqual(status.displayBadge, "오늘")
        XCTAssertFalse(status.isStale)
    }

    func testTenDaysAgoActivityIsActive() {
        let now = Date()
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: now)!

        let status = useCase.execute(
            latestDate: tenDaysAgo,
            currentDate: now,
            warningThreshold: 14,
            staleThreshold: 30
        )

        XCTAssertEqual(status.elapsedDays, 10)
        XCTAssertEqual(status.displayBadge, "D+10")
        XCTAssertFalse(status.isStale)
    }

    func testTwentyDaysAgoIsWarning() {
        let now = Date()
        let twentyDaysAgo = calendar.date(byAdding: .day, value: -20, to: now)!

        let status = useCase.execute(
            latestDate: twentyDaysAgo,
            currentDate: now,
            warningThreshold: 14,
            staleThreshold: 30
        )

        XCTAssertEqual(status.elapsedDays, 20)
        XCTAssertEqual(status.displayBadge, "D+20")
        XCTAssertFalse(status.isStale)
        if case .warning = status {
            // Success
        } else {
            XCTFail("Expected .warning but got \(status)")
        }
    }

    func testFortyFiveDaysAgoIsStale() {
        let now = Date()
        let fortyFiveDaysAgo = calendar.date(byAdding: .day, value: -45, to: now)!

        let status = useCase.execute(
            latestDate: fortyFiveDaysAgo,
            currentDate: now,
            warningThreshold: 14,
            staleThreshold: 30
        )

        XCTAssertEqual(status.elapsedDays, 45)
        XCTAssertEqual(status.displayBadge, "D+45")
        XCTAssertTrue(status.isStale)
    }
}

// MARK: - Mock Services for Testing
final class MockDockBadgeService: DockBadgeServiceProtocol, @unchecked Sendable {
    var lastBadgeLabel: String?

    func setBadgeLabel(_ label: String?) {
        self.lastBadgeLabel = label
    }
}

final class UpdateDockBadgeUseCaseTests: XCTestCase {
    func testBadgeCountReflectsStaleRepositories() {
        let mockBadge = MockDockBadgeService()
        let useCase = UpdateDockBadgeUseCase(badgeService: mockBadge)

        let calendar = Calendar.current
        let now = Date()
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now)!
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: now)!

        let repo1 = RepositoryItem(
            id: 1, name: "stale-repo-1", fullName: "user/stale-repo-1",
            owner: "user", htmlUrl: URL(string: "https://github.com")!,
            pushedAt: sixtyDaysAgo
        )
        let repo2 = RepositoryItem(
            id: 2, name: "stale-repo-2", fullName: "user/stale-repo-2",
            owner: "user", htmlUrl: URL(string: "https://github.com")!,
            pushedAt: sixtyDaysAgo
        )
        let repo3 = RepositoryItem(
            id: 3, name: "active-repo", fullName: "user/active-repo",
            owner: "user", htmlUrl: URL(string: "https://github.com")!,
            pushedAt: fiveDaysAgo
        )

        let settings = AppSettings(staleThresholdDays: 30, isDockBadgeEnabled: true)
        useCase.execute(repositories: [repo1, repo2, repo3], settings: settings)

        XCTAssertEqual(mockBadge.lastBadgeLabel, "2")
    }

    func testBadgeIsClearedWhenDisabled() {
        let mockBadge = MockDockBadgeService()
        let useCase = UpdateDockBadgeUseCase(badgeService: mockBadge)

        let settings = AppSettings(staleThresholdDays: 30, isDockBadgeEnabled: false)
        useCase.execute(repositories: [], settings: settings)

        XCTAssertNil(mockBadge.lastBadgeLabel)
    }
}

final class AppSettingsMonitoringTests: XCTestCase {
    func testRepoNotMonitoredBeforeInitialSelection() {
        var settings = AppSettings(hasCompletedInitialSelection: false)
        settings.monitoredRepoIds = [1, 2, 3]

        // 초기 선택을 완료하기 전에는 항상 false
        XCTAssertFalse(settings.isRepoMonitored(1))
        XCTAssertFalse(settings.isRepoMonitored(2))
    }

    func testRepoMonitoredAfterInitialSelection() {
        var settings = AppSettings(hasCompletedInitialSelection: true)
        settings.monitoredRepoIds = [10, 20]
        settings.ignoredRepoIds = [30]

        XCTAssertTrue(settings.isRepoMonitored(10))
        XCTAssertTrue(settings.isRepoMonitored(20))
        XCTAssertFalse(settings.isRepoMonitored(30))
        XCTAssertFalse(settings.isRepoMonitored(99)) // monitoredRepoIds에 없는 ID
    }
}

