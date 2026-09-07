import Foundation

/// 저장소의 마지막 활동일 기준 방치 상태를 계산하는 Use Case
public struct CalculateStaleStatusUseCase: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// 마지막 활동일자와 설정값을 바탕으로 방치 상태를 계산합니다.
    public func execute(
        latestDate: Date?,
        currentDate: Date = Date(),
        warningThreshold: Int = 14,
        staleThreshold: Int = 30
    ) -> StaleStatus {
        guard let latestDate = latestDate else {
            return .unknown
        }

        let startOfLatest = calendar.startOfDay(for: latestDate)
        let startOfCurrent = calendar.startOfDay(for: currentDate)

        let components = calendar.dateComponents([.day], from: startOfLatest, to: startOfCurrent)
        let days = max(0, components.day ?? 0)

        if days >= staleThreshold {
            return .stale(days: days)
        } else if days >= warningThreshold {
            return .warning(days: days)
        } else {
            return .active(days: days)
        }
    }
}
