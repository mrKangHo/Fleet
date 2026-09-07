import SwiftUI

public struct SidebarView: View {
    @ObservedObject var viewModel: RepositoryListViewModel
    @Binding var isSettingsPresented: Bool

    public init(viewModel: RepositoryListViewModel, isSettingsPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isSettingsPresented = isSettingsPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 상단 헤더 & 검색 & 인터랙티브 통계 필터 바
            VStack(spacing: 10) {
                // Stitch 스타일 상단 헤더: Repositories + Count Pill
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill.badge.gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                        Text("Repositories")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }

                    Spacer()

                    Text("\(viewModel.repositories.count) Repos")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.accentColor.opacity(0.14))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)

                // 검색창 (Stitch: Filter repositories...)
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))

                    TextField("Filter repositories...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))

                    if !viewModel.searchQuery.isEmpty {
                        Button(action: { viewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary.opacity(0.8))
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                )

                // 필터 캡슐 버튼 바 (Horizontal Scrollable or Grid)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterPill(
                            title: "관리 중",
                            count: viewModel.repositories.count,
                            isSelected: viewModel.selectedFilter == .all,
                            accentColor: .primary
                        ) {
                            withAnimation(.spring(response: 0.25)) { viewModel.selectedFilter = .all }
                        }

                        filterPill(
                            title: "방치됨",
                            count: viewModel.staleCount,
                            isSelected: viewModel.selectedFilter == .stale,
                            accentColor: AppTheme.staleRose
                        ) {
                            withAnimation(.spring(response: 0.25)) { viewModel.selectedFilter = .stale }
                        }

                        filterPill(
                            title: "주의",
                            count: warningCount,
                            isSelected: viewModel.selectedFilter == .warning,
                            accentColor: AppTheme.warningAmber
                        ) {
                            withAnimation(.spring(response: 0.25)) { viewModel.selectedFilter = .warning }
                        }

                        filterPill(
                            title: "메모",
                            count: memoCount,
                            isSelected: viewModel.selectedFilter == .withMemos,
                            accentColor: .accentColor
                        ) {
                            withAnimation(.spring(response: 0.25)) { viewModel.selectedFilter = .withMemos }
                        }

                        if viewModel.ignoredCount > 0 {
                            filterPill(
                                title: "제외됨",
                                count: viewModel.ignoredCount,
                                isSelected: viewModel.selectedFilter == .ignored,
                                accentColor: .secondary
                            ) {
                                withAnimation(.spring(response: 0.25)) { viewModel.selectedFilter = .ignored }
                            }
                        }
                    }
                }

                // 정렬 옵션 및 저장소 관리 버튼 바
                HStack {
                    Text("\(viewModel.filteredRepositories.count)개 표시 중")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Menu {
                        ForEach(RepositoryListViewModel.SortOption.allCases) { sort in
                            Button(action: {
                                withAnimation { viewModel.selectedSort = sort }
                            }) {
                                if viewModel.selectedSort == sort {
                                    Label(sort.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(LocalizedStringKey(sort.rawValue))
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 10))
                            Text(LocalizedStringKey(viewModel.selectedSort.rawValue))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // MARK: - 저장소 목록
            if viewModel.isLoading && viewModel.repositories.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.1)
                    Text("GitHub 저장소 동기화 중...")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredRepositories.isEmpty {
                VStack(spacing: 12) {
                    Spacer()

                    if !viewModel.allFetchedRepositories.isEmpty && !viewModel.currentSettings.hasCompletedInitialSelection {
                        Image(systemName: "checklist")
                            .font(.system(size: 38))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.accentColor)

                        Text("관리할 저장소 선택 필요")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)

                        Text("동기화된 \(viewModel.allFetchedRepositories.count)개 저장소 중 모니터링 및 AI 작업을 진행할 저장소를 선택해주세요.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button("저장소 선택 마법사 열기") {
                            viewModel.isSelectionSheetPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)

                    } else if viewModel.currentSettings.githubToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "key.fill")
                            .font(.system(size: 38))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.accentColor.opacity(0.8))

                        Text("GitHub 토큰 미등록")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)

                        Text("저장소 목록을 불러오려면 GitHub Personal Access Token을 먼저 설정해주세요.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button("GitHub 토큰 설정하기") {
                            isSettingsPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)

                    } else if viewModel.repositories.isEmpty {
                        Image(systemName: "eye.slash.circle.fill")
                            .font(.system(size: 38))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)

                        Text("관리 중인 저장소가 없습니다")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)

                        Text("선택된 저장소가 없거나 모두 제외되었습니다. 관리할 저장소를 추가하세요.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button("저장소 목록 수정") {
                            viewModel.isSelectionSheetPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)

                    } else {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 38))
                            .foregroundColor(.secondary.opacity(0.6))

                        Text("검색 조건에 맞는 저장소가 없습니다")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $viewModel.selectedRepositoryId) {
                    if viewModel.selectedFilter == .all && viewModel.searchQuery.isEmpty {
                        // Stitch 섹션 그룹화 렌더링
                        if !staleOrWarningRepos.isEmpty {
                            Section {
                                ForEach(staleOrWarningRepos) { repo in
                                    repoRow(repo)
                                }
                            } header: {
                                HStack(spacing: 5) {
                                    Text("⚠️ 방치 주의 (STALE)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppTheme.staleRose)
                                    Spacer()
                                    Text("\(staleOrWarningRepos.count)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(AppTheme.staleRose.opacity(0.16))
                                        .foregroundColor(AppTheme.staleRose)
                                        .clipShape(Capsule())
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if !activeRepos.isEmpty {
                            Section {
                                ForEach(activeRepos) { repo in
                                    repoRow(repo)
                                }
                            } header: {
                                HStack(spacing: 5) {
                                    Text("🟢 최근 활동 (ACTIVE)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppTheme.activeGreen)
                                    Spacer()
                                    Text("\(activeRepos.count)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(AppTheme.activeGreen.opacity(0.16))
                                        .foregroundColor(AppTheme.activeGreen)
                                        .clipShape(Capsule())
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if !otherRepos.isEmpty {
                            Section {
                                ForEach(otherRepos) { repo in
                                    repoRow(repo)
                                }
                            } header: {
                                HStack(spacing: 5) {
                                    Text("📦 전체 저장소 (ALL REPOS)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(otherRepos.count)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.primary.opacity(0.08))
                                        .foregroundColor(.secondary)
                                        .clipShape(Capsule())
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } else {
                        // 검색/필터 적용 시 플랫 목록 렌더링
                        ForEach(viewModel.filteredRepositories) { repo in
                            repoRow(repo)
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            // MARK: - 하단 글래스 툴바 (Stitch Style: + Add Repo & Settings)
            HStack(spacing: 8) {
                if let user = viewModel.authenticatedUser {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                            )

                        Text(user)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                } else {
                    Text("미연동 상태")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // + Add Repo (저장소 목록 추가/수정) 버튼
                Button(action: {
                    viewModel.isSelectionSheetPresented = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add Repo")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("관리할 저장소 추가 및 편집")

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.65)
                        .frame(width: 18, height: 18)
                } else {
                    Button(action: {
                        Task { await viewModel.refreshRepositories() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("저장소 새로고침 (Cmd+R)")
                    .keyboardShortcut("r", modifiers: .command)
                }

                Button(action: {
                    isSettingsPresented = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("환경설정 (Cmd+,)")
                .keyboardShortcut(",", modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.stitchElevated)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(AppTheme.stitchBorder),
                alignment: .top
            )
        }
        .background(AppTheme.stitchContainerLowest)
    }

    // MARK: - Helper Views & Properties
    @ViewBuilder
    private func repoRow(_ repo: RepositoryItem) -> some View {
        let status = viewModel.staleStatus(for: repo)
        let isMonitored = viewModel.currentSettings.isRepoMonitored(repo.id)
        RepositoryRowView(repository: repo, status: status)
            .tag(repo.id)
            .contextMenu {
                if isMonitored {
                    Button(role: .destructive, action: {
                        viewModel.ignoreRepository(repoId: repo.id)
                    }) {
                        Label("이 저장소 모니터링 제외 (숨기기)", systemImage: "eye.slash")
                    }
                } else {
                    Button(action: {
                        viewModel.restoreRepository(repoId: repo.id)
                    }) {
                        Label("다시 모니터링 목록에 포함", systemImage: "plus.circle")
                    }
                }
                Divider()
                Button(action: {
                    viewModel.isSelectionSheetPresented = true
                }) {
                    Label("관리 저장소 목록 전체 편집...", systemImage: "checklist")
                }
            }
    }

    private var staleOrWarningRepos: [RepositoryItem] {
        viewModel.filteredRepositories.filter { repo in
            let s = viewModel.staleStatus(for: repo)
            if case .stale = s { return true }
            if case .warning = s { return true }
            return false
        }
    }

    private var activeRepos: [RepositoryItem] {
        viewModel.filteredRepositories.filter { repo in
            let s = viewModel.staleStatus(for: repo)
            if case .active = s { return true }
            return false
        }
    }

    private var otherRepos: [RepositoryItem] {
        viewModel.filteredRepositories.filter { repo in
            let s = viewModel.staleStatus(for: repo)
            if case .unknown = s { return true }
            return false
        }
    }

    // MARK: - Filter Pill View Builder
    private func filterPill(
        title: String,
        count: Int,
        isSelected: Bool,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))

                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.white.opacity(0.25) : accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? accentColor : Color.primary.opacity(0.04))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private var warningCount: Int {
        viewModel.repositories.filter { repo in
            let s = viewModel.staleStatus(for: repo)
            if case .warning = s { return true }
            return false
        }.count
    }

    private var memoCount: Int {
        viewModel.repositories.filter { $0.memoCount > 0 }.count
    }
}
