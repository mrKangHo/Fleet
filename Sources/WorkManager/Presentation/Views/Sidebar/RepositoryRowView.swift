import SwiftUI

public struct RepositoryRowView: View {
    public let repository: RepositoryItem
    public let status: StaleStatus
    @State private var isHovered = false

    public init(repository: RepositoryItem, status: StaleStatus) {
        self.repository = repository
        self.status = status
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // 1열: 상태 인디케이터 + 이름 + 잠금/포크 + D-day 뱃지
            HStack(spacing: 8) {
                // 상태 발광 점
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.6), radius: 3)

                Text(repository.name)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                if repository.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                if repository.isFork {
                    Image(systemName: "tuningfork")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 6)

                // D-day 뱃지 (Glass Capsule)
                Text(status.displayBadge)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(statusBadgeBackground)
                    .foregroundColor(statusBadgeForeground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(statusBadgeForeground.opacity(0.25), lineWidth: 0.8)
                    )
            }

            // 2열: 저장소 설명 (1줄 요약)
            if let desc = repository.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // 3열: 하단 메타정보 (언어 태그, 커밋 상대시간, 메모 개수)
            HStack(spacing: 10) {
                // 주 언어 표시 (고유 색상 점)
                if let lang = repository.language {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.languageColor(for: lang))
                            .frame(width: 7, height: 7)
                        Text(lang)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                // 마지막 활동 일자
                if let date = repository.latestActivityDate {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(formatShortDate(date))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()

                // 등록된 메모 카운트 뱃지
                if repository.memoCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "checklist")
                            .font(.system(size: 9))
                        Text("\(repository.memoCount)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .active:
            return AppTheme.activeGreen
        case .warning:
            return AppTheme.warningAmber
        case .stale:
            return AppTheme.staleRose
        case .unknown:
            return Color.gray
        }
    }

    private var statusBadgeBackground: Color {
        switch status {
        case .active:
            return AppTheme.activeGreen.opacity(0.14)
        case .warning:
            return AppTheme.warningAmber.opacity(0.14)
        case .stale:
            return AppTheme.staleRose.opacity(0.16)
        case .unknown:
            return Color.secondary.opacity(0.1)
        }
    }

    private var statusBadgeForeground: Color {
        switch status {
        case .active:
            return AppTheme.activeGreen
        case .warning:
            return AppTheme.warningAmber
        case .stale:
            return AppTheme.staleRose
        case .unknown:
            return .secondary
        }
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.MM.dd"
        return formatter.string(from: date)
    }
}
