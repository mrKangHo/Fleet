import Foundation
import UserNotifications

/// macOS 시스템 알림 관리 구현체
public final class NotificationManager: SystemNotificationServiceProtocol, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    /// 알림 권한 요청
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("[NotificationManager] Authorization failed: \(error)")
            return false
        }
    }

    /// 단일 방치 저장소 알림 전송
    public func sendStaleNotification(repositoryName: String, elapsedDays: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "저장소 방치 알림 ⚠️"
        content.body = "[\(repositoryName)] 저장소가 마지막 커밋 후 \(elapsedDays)일 동안 업데이트되지 않았습니다."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "stale-repo-\(repositoryName)",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    /// 복수 방치 저장소 요약 알림 전송
    public func sendStaleSummaryNotification(count: Int, thresholdDays: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "방치된 저장소 확인 필요 ⚠️"
        content.body = "설정된 기준일(\(thresholdDays)일)을 초과하여 방치된 저장소가 총 \(count)개 있습니다."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "stale-summary-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }
}
