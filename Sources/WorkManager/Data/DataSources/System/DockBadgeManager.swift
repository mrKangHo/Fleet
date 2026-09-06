import AppKit
import Foundation

/// macOS 독(Dock) 뱃지 관리 구현체
public final class DockBadgeManager: DockBadgeServiceProtocol, @unchecked Sendable {
    public init() {}

    public func setBadgeLabel(_ label: String?) {
        Task { @MainActor in
            NSApplication.shared.dockTile.badgeLabel = label
        }
    }
}
