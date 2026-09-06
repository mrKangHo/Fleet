import Foundation

/// macOS Dock 아이콘 뱃지 제어 인터페이스
public protocol DockBadgeServiceProtocol: Sendable {
    func setBadgeLabel(_ label: String?)
}

/// 방치된 저장소 개수를 계산하여 macOS Dock 뱃지를 갱신하는 Use Case
public struct UpdateDockBadgeUseCase: Sendable {
    private let badgeService: DockBadgeServiceProtocol
    private let calculateStaleUseCase: CalculateStaleStatusUseCase

    public init(
        badgeService: DockBadgeServiceProtocol,
        calculateStaleUseCase: CalculateStaleStatusUseCase = CalculateStaleStatusUseCase()
    ) {
        self.badgeService = badgeService
        self.calculateStaleUseCase = calculateStaleUseCase
    }

    /// 저장소 목록과 설정값을 바탕으로 Dock 뱃지를 갱신합니다.
    public func execute(repositories: [RepositoryItem], settings: AppSettings) {
        guard settings.isDockBadgeEnabled else {
            badgeService.setBadgeLabel(nil)
            return
        }

        let staleCount = repositories.filter { repo in
            let status = calculateStaleUseCase.execute(
                latestDate: repo.latestActivityDate,
                warningThreshold: settings.warningThresholdDays,
                staleThreshold: settings.staleThresholdDays
            )
            return status.isStale
        }.count

        if staleCount > 0 {
            badgeService.setBadgeLabel("\(staleCount)")
        } else {
            badgeService.setBadgeLabel(nil)
        }
    }
}
