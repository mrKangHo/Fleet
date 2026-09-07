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
    @AppStorage("workmanager_app_language") private var appLanguageRaw: String = AppLanguage.system.rawValue
    @Namespace private var navTabHighlight

    private var appLocale: Locale {
        (AppLanguage(rawValue: appLanguageRaw) ?? .system).locale
    }

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
            .navigationTitle(detailViewModel.repository?.name ?? "Fleet")
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
            .environment(\.locale, appLocale)
        }
        .sheet(isPresented: $listViewModel.isSelectionSheetPresented) {
            RepositorySelectionSheet(viewModel: listViewModel)
                .environment(\.locale, appLocale)
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
            kanbanTab

            if selectedNavTab == .kanban {
                viewModePicker
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(AppTheme.stitchBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var kanbanTab: some View {
        HStack(spacing: 3) {
            navTabButton(for: .kanban)
        }
        .padding(3)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .clipShape(Capsule())
    }

    private var viewModePicker: some View {
        Picker("보기", selection: $memoViewMode) {
            Label("Board", systemImage: "rectangle.split.3x1").tag(MemoViewMode.kanban)
            Label("List", systemImage: "list.bullet").tag(MemoViewMode.list)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .labelStyle(.iconOnly)
        .frame(width: 72)
    }

    private func navTabButton(for tab: NavigationTab) -> some View {
        let isSelected = (selectedNavTab == tab)
        return Button(action: {
            withAnimation(AppTheme.fluidSpring) { selectedNavTab = tab }
        }) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(LocalizedStringKey(tab.rawValue))
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.15))
                        .matchedGeometryEffect(id: "navTabHighlight", in: navTabHighlight)
                }
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.tapFeedback)
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
