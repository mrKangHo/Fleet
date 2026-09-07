import SwiftUI
import AppKit

/// Stitch Design: WorkManager — macOS Menu Bar Extra Popover Widget
public struct MenuBarExtraView: View {
    let appEnv: AppEnvironment

    @State private var repositories: [RepositoryItem] = []
    @State private var memos: [MemoItem] = []
    @State private var selectedRepoId: Int? = nil
    @State private var quickTaskText: String = ""
    @State private var isLoading: Bool = false

    public init(environment: AppEnvironment) {
        self.appEnv = environment
    }

    private var settings: AppSettings {
        appEnv.settingsRepository.loadSettings()
    }

    private var staleRepos: [RepositoryItem] {
        var results: [RepositoryItem] = []
        for repo in repositories {
            let status = appEnv.calculateStaleStatusUseCase.execute(
                latestDate: repo.lastCommitDate,
                warningThreshold: settings.staleThresholdDays,
                staleThreshold: settings.criticalThresholdDays
            )
            if status.isStale || status.isWarning {
                results.append(repo)
            }
        }
        return results
    }

    public var body: some View {
        VStack(spacing: 12) {
            // MARK: - 1. Popover Header
            headerBar

            // MARK: - 2. Quick Task Input Bar
            quickAddBar

            // MARK: - 3. Monitored Repos & D-Day Tracker
            monitoredReposSection

            // MARK: - 4. Today's Focus
            todaysFocusSection

            Divider()

            // MARK: - 5. Footer Quick Actions
            footerBar
        }
        .padding(14)
        .frame(width: 380)
        .background(.ultraThinMaterial)
        .task {
            await loadData()
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("WorkManager")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("v1.0")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(staleRepos.isEmpty ? AppTheme.activeGreen : AppTheme.staleRose)
                            .frame(width: 5, height: 5)
                        Text(staleRepos.isEmpty ? "모든 저장소 정상 활동 중" : "\(staleRepos.count)개 저장소 방치 경고")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(staleRepos.isEmpty ? AppTheme.activeGreen : AppTheme.staleRose)
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: {
                    Task { await loadData() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("새로고침")

                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("메인 앱 열기")
            }
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle")
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            TextField("+ 새 작업 추가 (Enter)...", text: $quickTaskText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit {
                    submitQuickTask()
                }

            if !repositories.isEmpty {
                Menu {
                    ForEach(repositories) { repo in
                        Button(action: { selectedRepoId = repo.id }) {
                            Text(repo.name)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(selectedRepoName)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .frame(maxWidth: 80)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
            }

            Button(action: submitQuickTask) {
                Text("↵")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .disabled(quickTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private var monitoredReposSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("방치 주의 & 모니터링 상태")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(repositories.count)개 추적 중")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(displayRepos) { repo in
                        let status = appEnv.calculateStaleStatusUseCase.execute(
                            latestDate: repo.lastCommitDate,
                            warningThreshold: settings.staleThresholdDays,
                            staleThreshold: settings.criticalThresholdDays
                        )

                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(status))
                                .frame(width: 6, height: 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("\(status.elapsedDays)일 전 마지막 커밋 • \(repo.defaultBranch)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(status.stitchBadge)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusColor(status).opacity(0.12))
                                .foregroundColor(statusColor(status))
                                .clipShape(Capsule())
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.025))
                        .cornerRadius(6)
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    private var todaysFocusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("오늘의 집중 작업 (TODAY'S FOCUS)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                let completed = memos.filter { $0.isCompleted }.count
                Text("\(completed)/\(memos.count) 완료")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if memos.isEmpty {
                Text("등록된 작업이 없습니다.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(Array(memos.prefix(5))) { memo in
                            HStack(spacing: 8) {
                                Button(action: {
                                    Task {
                                        _ = try? await appEnv.manageMemoUseCase.toggleCompletion(for: memo)
                                        await loadData()
                                    }
                                }) {
                                    Image(systemName: memo.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(memo.isCompleted ? AppTheme.activeGreen : .secondary)
                                        .font(.system(size: 13))
                                }
                                .buttonStyle(.plain)

                                Text(memo.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(memo.isCompleted ? .secondary : .primary)
                                    .strikethrough(memo.isCompleted)
                                    .lineLimit(1)

                                Spacer()

                                Text(memo.priority.rawValue)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(priorityColor(memo.priority).opacity(0.15))
                                    .foregroundColor(priorityColor(memo.priority))
                                    .cornerRadius(3)
                            }
                            .padding(6)
                            .background(Color.primary.opacity(0.02))
                            .cornerRadius(5)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Button("메인 앱 열기 (⌘1)") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)

            Spacer()

            Button("종료 (⌘Q)") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.staleRose)
        }
    }

    // MARK: - Helpers

    private var selectedRepoName: String {
        if let id = selectedRepoId, let repo = repositories.first(where: { $0.id == id }) {
            return repo.name
        }
        return repositories.first?.name ?? "선택"
    }

    private var displayRepos: [RepositoryItem] {
        if staleRepos.isEmpty {
            return Array(repositories.prefix(4))
        }
        return staleRepos
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        if let fetched = try? await appEnv.fetchRepositoriesUseCase.execute(token: settings.githubToken, settings: settings) {
            repositories = fetched
            if selectedRepoId == nil {
                selectedRepoId = fetched.first?.id
            }
        }

        if let targetId = selectedRepoId ?? repositories.first?.id {
            if let fetchedMemos = try? await appEnv.manageMemoUseCase.getMemos(for: targetId) {
                memos = fetchedMemos
            }
        }
    }

    private func submitQuickTask() {
        let trimmed = quickTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let targetId = selectedRepoId ?? repositories.first?.id else { return }

        Task {
            _ = try? await appEnv.manageMemoUseCase.addMemo(
                repositoryId: targetId,
                title: trimmed,
                content: "",
                priority: .medium
            )
            quickTaskText = ""
            await loadData()
        }
    }

    private func statusColor(_ status: StaleStatus) -> Color {
        if status.isStale { return AppTheme.staleRose }
        if status.isWarning { return AppTheme.warningAmber }
        return AppTheme.activeGreen
    }

    private func priorityColor(_ priority: MemoItem.Priority) -> Color {
        switch priority {
        case .high: return AppTheme.staleRose
        case .medium: return AppTheme.warningAmber
        case .low: return Color.blue
        }
    }
}
