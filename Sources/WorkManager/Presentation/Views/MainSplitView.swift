import SwiftUI

public struct MainSplitView: View {
    @StateObject private var listViewModel: RepositoryListViewModel
    @StateObject private var detailViewModel: RepositoryDetailViewModel
    @State private var isSettingsPresented = false

    public enum NavigationTab: String, CaseIterable, Identifiable {
        case kanban = "Kanban Tasks"
        case repoHealth = "Repo Health"
        case workflows = "Agent Workflows"
        case cliEnvs = "CLI & Envs"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .kanban: return "rectangle.split.3x1.fill"
            case .repoHealth: return "heart.text.square.fill"
            case .workflows: return "cpu.fill"
            case .cliEnvs: return "terminal.fill"
            }
        }
    }

    @State private var selectedNavTab: NavigationTab = .kanban
    @AppStorage("workmanager_memo_view_mode") private var memoViewMode: MemoViewMode = .kanban

    public init(environment: AppEnvironment = .shared) {
        self._listViewModel = StateObject(wrappedValue: RepositoryListViewModel(environment: environment))
        self._detailViewModel = StateObject(wrappedValue: RepositoryDetailViewModel(environment: environment))
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: listViewModel,
                isSettingsPresented: $isSettingsPresented
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            VStack(spacing: 0) {
                topNavigationBar
                Divider()
                    .overlay(AppTheme.stitchBorder)
                selectedTabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.stitchBackground)
            }
            .navigationTitle(detailViewModel.repository?.name ?? "WorkManager")
            .background(AppTheme.stitchBackground)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView {
                Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    await listViewModel.refreshRepositories()
                }
            }
        }
        .sheet(isPresented: $listViewModel.isSelectionSheetPresented) {
            RepositorySelectionSheet(viewModel: listViewModel)
        }
        .onChange(of: listViewModel.selectedRepositoryId) { _, newId in
            if let newId = newId,
               let repo = listViewModel.repositories.first(where: { $0.id == newId }) {
                detailViewModel.setRepository(repo)
            } else {
                detailViewModel.setRepository(nil)
            }
        }
        .task {
            listViewModel.loadSettings()
            if listViewModel.currentSettings.githubToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isSettingsPresented = true
            } else {
                await listViewModel.refreshRepositories(silentIfNoToken: true)
            }
        }
        .alert("안내", isPresented: Binding(
            get: { listViewModel.errorMessage != nil },
            set: { if !$0 { listViewModel.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { listViewModel.errorMessage = nil }
            if listViewModel.currentSettings.githubToken.isEmpty {
                Button("설정 열기") {
                    listViewModel.errorMessage = nil
                    isSettingsPresented = true
                }
            }
        } message: {
            Text(listViewModel.errorMessage ?? "")
        }
    }

    // MARK: - Top Navigation Bar (Stitch)
    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            leadingProjectInfo
            Spacer()
            centerNavigationTabs
            Spacer()
            trailingActions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.stitchElevated)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppTheme.stitchBorder),
            alignment: .bottom
        )
    }

    private var leadingProjectInfo: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill.badge.gearshape")
                .foregroundColor(.accentColor)
                .font(.system(size: 14))

            Text("WorkManager")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
    }

    private var centerNavigationTabs: some View {
        HStack(spacing: 3) {
            ForEach(NavigationTab.allCases) { tab in
                navTabButton(for: tab)
            }
        }
        .padding(3)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .clipShape(Capsule())
    }

    private func navTabButton(for tab: NavigationTab) -> some View {
        let isSelected = (selectedNavTab == tab)
        return Button(action: {
            withAnimation(.spring(response: 0.25)) { selectedNavTab = tab }
        }) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11))
                Text(tab.rawValue)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var trailingActions: some View {
        HStack(spacing: 8) {
            if selectedNavTab == .kanban {
                Picker("보기", selection: $memoViewMode) {
                    Label("Board", systemImage: "rectangle.split.3x1").tag(MemoViewMode.kanban)
                    Label("List", systemImage: "list.bullet").tag(MemoViewMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            Button(action: {
                listViewModel.searchQuery = ""
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                    Text("Search (⌘K)")
                        .font(.system(size: 10.5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .foregroundColor(.secondary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)

            Button(action: { isSettingsPresented = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("환경설정 (⌘,)")
        }
    }

    // MARK: - Selected Tab Content View
    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedNavTab {
        case .kanban:
            RepositoryDetailView(
                viewModel: detailViewModel,
                onMemoCountChanged: { newCount in
                    if let repoId = detailViewModel.repository?.id {
                        listViewModel.updateMemoCount(for: repoId, count: newCount)
                    }
                }
            )
        case .repoHealth:
            RepoHealthDashboardView(
                repositories: listViewModel.repositories,
                settings: listViewModel.currentSettings,
                onSelectRepo: { repo in
                    listViewModel.selectedRepositoryId = repo.id
                    selectedNavTab = .kanban
                }
            )
        case .workflows:
            AgentWorkflowsView(
                selectedRepo: detailViewModel.repository,
                memos: detailViewModel.memos,
                settings: listViewModel.currentSettings,
                onOpenSettings: { isSettingsPresented = true },
                onExecuteTask: { memo in
                    Task {
                        await detailViewModel.executeTask(for: memo)
                    }
                },
                onOpenTerminal: {
                    if let repo = detailViewModel.repository {
                        TerminalSessionManager.shared.togglePanel(
                            for: repo.id,
                            name: repo.name,
                            localPath: detailViewModel.localDirectoryPath
                        )
                    }
                }
            )
        case .cliEnvs:
            CliEnvironmentsView(
                localPath: detailViewModel.localDirectoryPath,
                settings: listViewModel.currentSettings,
                onOpenSettings: { isSettingsPresented = true },
                onChooseFolder: { detailViewModel.chooseLocalFolder() },
                onOpenInFinder: {
                    if let path = detailViewModel.localDirectoryPath {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                },
                onOpenTerminal: {
                    detailViewModel.openInExternalTerminal()
                }
            )
        }
    }
}
