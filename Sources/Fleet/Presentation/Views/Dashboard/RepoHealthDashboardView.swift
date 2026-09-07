import SwiftUI

/// 저장소 헬스 및 D-Day 방치 현황 대시보드 뷰 (Stitch: Repo Health)
public struct RepoHealthDashboardView: View {
    let repositories: [RepositoryItem]
    let settings: AppSettings
    let calculateStaleStatusUseCase: CalculateStaleStatusUseCase
    let onSelectRepo: (RepositoryItem) -> Void

    public init(
        repositories: [RepositoryItem],
        settings: AppSettings = .default,
        calculateStaleStatusUseCase: CalculateStaleStatusUseCase = CalculateStaleStatusUseCase(),
        onSelectRepo: @escaping (RepositoryItem) -> Void
    ) {
        self.repositories = repositories
        self.settings = settings
        self.calculateStaleStatusUseCase = calculateStaleStatusUseCase
        self.onSelectRepo = onSelectRepo
    }

    private var criticalRepos: [RepositoryItem] {
        repositories.filter { repo in
            let days = status(for: repo).elapsedDays
            return days >= settings.criticalThresholdDays
        }
    }

    private var staleRepos: [RepositoryItem] {
        repositories.filter { repo in
            let days = status(for: repo).elapsedDays
            return days >= settings.staleThresholdDays && days < settings.criticalThresholdDays
        }
    }

    private var watchRepos: [RepositoryItem] {
        repositories.filter { repo in
            let days = status(for: repo).elapsedDays
            return days >= settings.warningThresholdDays && days < settings.staleThresholdDays
        }
    }

    private var activeRepos: [RepositoryItem] {
        repositories.filter { repo in
            let days = status(for: repo).elapsedDays
            return days < settings.warningThresholdDays
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.activeGreen)
                            Text("Repository Health & D-Day Policy")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                        }
                        Text("Git 최근 활동 시점을 기준으로 계산된 저장소 생명주기 및 방치 리스크 분석 현황입니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("총 \(repositories.count)개 저장소 관리 중")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                }

                // MARK: - 4 Status Metric Cards (Stitch Health Metrics)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    metricCard(
                        title: "방치 위험 (Critical)",
                        count: criticalRepos.count,
                        threshold: "\(settings.criticalThresholdDays)일 이상",
                        color: Color(red: 0.85, green: 0.20, blue: 0.40),
                        icon: "exclamationmark.octagon.fill"
                    )
                    metricCard(
                        title: "방치 경고 (Stale)",
                        count: staleRepos.count,
                        threshold: "\(settings.staleThresholdDays)일 경과",
                        color: AppTheme.staleRose,
                        icon: "exclamationmark.triangle.fill"
                    )
                    metricCard(
                        title: "주의 (Watch)",
                        count: watchRepos.count,
                        threshold: "\(settings.warningThresholdDays)일 경과",
                        color: AppTheme.warningAmber,
                        icon: "clock.badge.exclamationmark.fill"
                    )
                    metricCard(
                        title: "최근 활동 (Active)",
                        count: activeRepos.count,
                        threshold: "활성 프로젝트",
                        color: AppTheme.activeGreen,
                        icon: "checkmark.circle.fill"
                    )
                }

                // MARK: - Detailed Repository Health Table
                VStack(alignment: .leading, spacing: 12) {
                    Text("전체 저장소 활동도 매트릭스")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)

                    VStack(spacing: 8) {
                        ForEach(repositories) { repo in
                            let st = status(for: repo)
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(statusColor(for: st))
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(repo.fullName)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        if repo.isPrivate {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    if let msg = repo.lastCommitMessage {
                                        Text(msg)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if let lang = repo.language {
                                    Text(lang)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.languageColor(for: lang).opacity(0.12))
                                        .foregroundColor(AppTheme.languageColor(for: lang))
                                        .clipShape(Capsule())
                                }

                                Text(st.stitchBadge)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(statusColor(for: st).opacity(0.14))
                                    .foregroundColor(statusColor(for: st))
                                    .clipShape(Capsule())

                                Button("작업 열기") {
                                    onSelectRepo(repo)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(10)
                            .glassCard(cornerRadius: 8)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func metricCard(title: String, count: Int, threshold: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            Text(threshold)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .glassCard(cornerRadius: 10)
    }

    private func status(for repo: RepositoryItem) -> StaleStatus {
        calculateStaleStatusUseCase.execute(
            latestDate: repo.latestActivityDate,
            warningThreshold: settings.warningThresholdDays,
            staleThreshold: settings.staleThresholdDays
        )
    }

    private func statusColor(for status: StaleStatus) -> Color {
        switch status {
        case .active: return AppTheme.activeGreen
        case .warning: return AppTheme.warningAmber
        case .stale(let days):
            return days >= settings.criticalThresholdDays ? Color(red: 0.85, green: 0.20, blue: 0.40) : AppTheme.staleRose
        case .unknown: return Color.gray
        }
    }
}
