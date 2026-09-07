import SwiftUI
import AppKit

/// Stitch Design: Fleet — macOS Menu Bar Extra Popover Widget
public struct MenuBarExtraView: View {
    @StateObject private var viewModel: MenuBarViewModel

    public init(environment: AppEnvironment) {
        self._viewModel = StateObject(wrappedValue: MenuBarViewModel(environment: environment))
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
            await viewModel.loadData()
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
                        Text("Fleet")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("v1.0")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.staleRepos.isEmpty ? AppTheme.activeGreen : AppTheme.staleRose)
                            .frame(width: 5, height: 5)
                        Text(viewModel.staleRepos.isEmpty ? "모든 저장소 정상 활동 중" : "\(viewModel.staleRepos.count)개 저장소 방치 경고")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(viewModel.staleRepos.isEmpty ? AppTheme.activeGreen : AppTheme.staleRose)
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: {
                    Task { await viewModel.loadData() }
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

            TextField("+ 새 작업 추가 (Enter)...", text: $viewModel.quickTaskText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit {
                    viewModel.submitQuickTask()
                }

            if !viewModel.repositories.isEmpty {
                Menu {
                    ForEach(viewModel.repositories) { repo in
                        Button(action: { viewModel.selectRepo(repo.id) }) {
                            Text(repo.name)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(viewModel.selectedRepoName)
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

            Button(action: viewModel.submitQuickTask) {
                Text("↵")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.quickTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                Text("\(viewModel.repositories.count)개 추적 중")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(viewModel.displayRepos) { repo in
                        let status = viewModel.staleStatus(for: repo)

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
                let completed = viewModel.memos.filter { $0.isCompleted }.count
                Text("\(completed)/\(viewModel.memos.count) 완료")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if viewModel.memos.isEmpty {
                Text("등록된 작업이 없습니다.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(Array(viewModel.memos.prefix(5))) { memo in
                            HStack(spacing: 8) {
                                Button(action: {
                                    Task { await viewModel.toggleCompletion(for: memo) }
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

                                Text(LocalizedStringKey(memo.priority.rawValue))
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
