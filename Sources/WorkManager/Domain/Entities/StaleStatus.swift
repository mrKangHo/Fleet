import Foundation

/// 저장소 방치 상태 및 경과 일수 엔티티
public enum StaleStatus: Hashable, Sendable {
    case active(days: Int)
    case warning(days: Int)
    case stale(days: Int)
    case unknown

    public var elapsedDays: Int {
        switch self {
        case .active(let days), .warning(let days), .stale(let days):
            return days
        case .unknown:
            return 0
        }
    }

    public var isStale: Bool {
        if case .stale = self { return true }
        return false
    }

    /// 화면 표시용 D+day 문자열 (예: "D+0", "D+45", "활동 없음")
    public var displayBadge: String {
        switch self {
        case .active(let days), .warning(let days), .stale(let days):
            if days == 0 {
                return "오늘"
            } else {
                return "D+\(days)"
            }
        case .unknown:
            return "기록 없음"
        }
    }

    /// 상태별 설명 문구
    public var description: String {
        switch self {
        case .active(let days):
            return days == 0 ? "오늘 업데이트됨" : "\(days)일 전 업데이트"
        case .warning(let days):
            return "\(days)일 경과 (업데이트 권장)"
        case .stale(let days):
            return "\(days)일 경과 (장기 방치)"
        case .unknown:
            return "업데이트 내역 없음"
        }
    }
}
