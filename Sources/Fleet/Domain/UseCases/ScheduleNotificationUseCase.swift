import Foundation

/// macOS 시스템 알림 서비스 인터페이스
public protocol SystemNotificationServiceProtocol: Sendable {
    func requestAuthorization() async -> Bool
    func sendStaleNotification(repositoryName: String, elapsedDays: Int) async
    func sendStaleSummaryNotification(count: Int, thresholdDays: Int) async
}

/// 방치 저장소 알림을 점검하고 발송하는 Use Case
public struct ScheduleNotificationUseCase: Sendable {
    private let notificationService: SystemNotificationServiceProtocol
    private let calculateStaleUseCase: CalculateStaleStatusUseCase

    public init(
        notificationService: SystemNotificationServiceProtocol,
        calculateStaleUseCase: CalculateStaleStatusUseCase = CalculateStaleStatusUseCase()
    ) {
        self.notificationService = notificationService
        self.calculateStaleUseCase = calculateStaleUseCase
    }

    /// 알림 권한 요청
    public func requestPermission() async -> Bool {
        await notificationService.requestAuthorization()
    }

    /// 저장소 목록을 점검하여 방치된 저장소에 대해 알림 발송
    public func execute(repositories: [RepositoryItem], settings: AppSettings) async {
        guard settings.isNotificationEnabled else { return }

        let staleRepos = repositories.filter { repo in
            let status = calculateStaleUseCase.execute(
                latestDate: repo.latestActivityDate,
                warningThreshold: settings.warningThresholdDays,
                staleThreshold: settings.staleThresholdDays
            )
            return status.isStale
        }

        guard !staleRepos.isEmpty else { return }

        if staleRepos.count == 1, let singleRepo = staleRepos.first {
            let status = calculateStaleUseCase.execute(
                latestDate: singleRepo.latestActivityDate,
                warningThreshold: settings.warningThresholdDays,
                staleThreshold: settings.staleThresholdDays
            )
            await notificationService.sendStaleNotification(
                repositoryName: singleRepo.name,
                elapsedDays: status.elapsedDays
            )
        } else {
            await notificationService.sendStaleSummaryNotification(
                count: staleRepos.count,
                thresholdDays: settings.staleThresholdDays
            )
        }
    }
}
