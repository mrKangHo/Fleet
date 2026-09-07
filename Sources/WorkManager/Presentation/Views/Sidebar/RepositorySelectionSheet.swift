import SwiftUI
import AppKit

/// Stitch Design: WorkManager — Add Repository Wizard Modal
public struct RepositorySelectionSheet: View {
    @ObservedObject var viewModel: RepositoryListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var sourceMode: AddRepoSourceMode = .gitHub
    @State private var selectedIds: Set<Int> = []
    @State private var searchText: String = ""
    @State private var selectedLanguageFilter: String = "전체"

    // 로컬 폴더 모드 상태
    @State private var localPathInput: String = "~/Documents/workmanager"
    @State private var localAliasInput: String = "workmanager"
    @State private var selectedWorkspaceTag: String = "Personal"
    @State private var selectedAgent: AppSettings.AIAgentPreset = .antigravity
    @State private var localStaleThresholdDays: Int = 14
    @State private var isNotificationEnabled: Bool = true
    @State private var isSmartScaffoldingEnabled: Bool = true

    // Git URL 모드 상태
    @State private var gitUrlInput: String = "https://github.com/"
    @State private var cloneDestInput: String = "~/Documents/workspace"
    @State private var isSubmoduleRecursive: Bool = true

    public enum AddRepoSourceMode: String, CaseIterable, Identifiable {
        case localFolder = "로컬 폴더 연결"
        case gitHub = "GitHub에서 가져오기"
        case gitUrl = "Git URL 복제"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .localFolder: return "folder.fill"
            case .gitHub: return "arrow.down.circle.fill"
            case .gitUrl: return "link"
            }
        }

        public var subtitle: String {
            switch self {
            case .localFolder: return "Mac에 클론된 프로젝트 디렉토리 탐색"
            case .gitHub: return "dev-workspace 연동됨"
            case .gitUrl: return "https://github.com/..."
            }
        }
    }

    public init(viewModel: RepositoryListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 상단 헤더 & Stepper
            headerSection

            Divider()

            // MARK: - 저장소 연결 방식 (3개 카드 선택기)
            sourceModeSelector
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            // MARK: - 선택된 모드에 따른 콘텐츠 영역
            Group {
                switch sourceMode {
                case .localFolder:
                    localFolderView
                case .gitHub:
                    gitHubImportView
                case .gitUrl:
                    gitUrlCloneView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // MARK: - 하단 액션 바
            footerActionBar
        }
        .frame(width: 680, height: 620)
        .onAppear {
            if let monitored = viewModel.currentSettings.monitoredRepoIds {
                self.selectedIds = monitored
            } else {
                let all = Set(viewModel.allFetchedRepositories.map { $0.id })
                self.selectedIds = all.subtracting(viewModel.currentSettings.ignoredRepoIds)
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 15))
                            .foregroundColor(.accentColor)
                        Text("새 저장소 등록 위저드 (Add Repository)")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                    }
                    Text("로컬 또는 원격 GitHub 저장소를 등록하고 D-Day 방치 추적 및 AI 자율 작업을 시작합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("닫기") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Stepper Pill
            HStack(spacing: 8) {
                stepBadge(num: "1", title: "저장소 소스 선택", isActive: true)
                Image(systemName: "chevron.right").font(.system(size: 8)).foregroundColor(.secondary)
                stepBadge(num: "2", title: "프로젝트 & CLI 설정", isActive: sourceMode == .localFolder)
                Image(systemName: "chevron.right").font(.system(size: 8)).foregroundColor(.secondary)
                stepBadge(num: "3", title: "D-Day 방치 정책", isActive: false)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func stepBadge(num: String, title: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(num)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .frame(width: 16, height: 16)
                .background(isActive ? Color.accentColor : Color.primary.opacity(0.1))
                .foregroundColor(isActive ? .white : .secondary)
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }

    private var sourceModeSelector: some View {
        HStack(spacing: 10) {
            ForEach(AddRepoSourceMode.allCases) { mode in
                let isSelected = sourceMode == mode
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        sourceMode = mode
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14))
                            .foregroundColor(isSelected ? .accentColor : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                                .foregroundColor(isSelected ? .primary : .secondary)

                            Text(mode.subtitle)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(10)
                    .background(isSelected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 1. 로컬 폴더 뷰
    private var localFolderView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 로컬 디렉토리 경로
                VStack(alignment: .leading, spacing: 5) {
                    Text("로컬 디렉토리 경로 (Local Path)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        TextField("경로 입력...", text: $localPathInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))

                        Button(action: chooseFolder) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                Text("폴더 찾아보기... ⌘O")
                            }
                            .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    HStack(spacing: 6) {
                        Circle().fill(AppTheme.activeGreen).frame(width: 5, height: 5)
                        Text("Git 감지됨: main branch | 변경사항 반영 가능")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                // 표시 별칭 & 워크스페이스 태그
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("표시 별칭 (Repository Alias)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        TextField("예: my-project", text: $localAliasInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("프로젝트 범주 (Workspace Tag)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ForEach(["Personal", "Work", "Lab / Test"], id: \.self) { tag in
                                Button(action: { selectedWorkspaceTag = tag }) {
                                    Text(tag)
                                        .font(.system(size: 11, weight: selectedWorkspaceTag == tag ? .bold : .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(selectedWorkspaceTag == tag ? Color.accentColor : Color.primary.opacity(0.04))
                                        .foregroundColor(selectedWorkspaceTag == tag ? .white : .secondary)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // 에이전트 및 방치 트리거 구성
                VStack(alignment: .leading, spacing: 10) {
                    Text("에이전트 및 방치 트리거 구성")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        Label("기본 AI 코딩 에이전트 CLI", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Picker("", selection: $selectedAgent) {
                            ForEach(AppSettings.AIAgentPreset.installedCases) { agent in
                                Text(agent.rawValue).tag(agent)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                    }

                    HStack {
                        Label("D-Day 방치(Stale) 감지 임계치", systemImage: "timer")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Picker("", selection: $localStaleThresholdDays) {
                            Text("7일").tag(7)
                            Text("14일 (기본)").tag(14)
                            Text("30일").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }

                    Toggle(isOn: $isNotificationEnabled) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("macOS 시스템 알림 및 주간 리포트")
                                .font(.system(size: 12, weight: .medium))
                            Text("방치 위험 저장소 발생 시 알림 센터 배너 발송")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $isSmartScaffoldingEnabled) {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text("✨ 초기 태스크 자동 생성 (Smart AI Scaffolding)")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("권장")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(3)
                            }
                            Text("README.md 및 코드 내 TODO 태그를 파싱하여 칸반 백로그 카드를 만듭니다.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
            }
            .padding(20)
        }
    }

    // MARK: - 2. GitHub 가져오기 뷰
    private var gitHubImportView: some View {
        VStack(spacing: 0) {
            // 필터 & 검색 바
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("저장소 검색...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // 언어 필터 칩
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(["전체", "Swift", "TypeScript", "Python", "Go", "Public", "Private"], id: \.self) { filter in
                            Button(action: { selectedLanguageFilter = filter }) {
                                Text(filter)
                                    .font(.system(size: 10, weight: selectedLanguageFilter == filter ? .bold : .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(selectedLanguageFilter == filter ? Color.accentColor : Color.primary.opacity(0.04))
                                    .foregroundColor(selectedLanguageFilter == filter ? .white : .secondary)
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Text("\(selectedIds.count) / \(viewModel.allFetchedRepositories.count)개 선택됨")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))

            Divider()

            // 저장소 목록
            let displayList = filteredRepos
            if displayList.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("표시할 저장소가 없습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(displayList) { repo in
                        let isChecked = selectedIds.contains(repo.id)
                        let status = viewModel.staleStatus(for: repo)

                        HStack(spacing: 10) {
                            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                .font(.system(size: 15))
                                .foregroundColor(isChecked ? .accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(repo.name)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))

                                    if repo.isPrivate {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text(status.stitchBadge)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(status.isStale ? AppTheme.staleRose.opacity(0.12) : AppTheme.activeGreen.opacity(0.12))
                                        .foregroundColor(status.isStale ? AppTheme.staleRose : AppTheme.activeGreen)
                                        .clipShape(Capsule())
                                }

                                if let desc = repo.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedIds.contains(repo.id) {
                                selectedIds.remove(repo.id)
                            } else {
                                selectedIds.insert(repo.id)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - 3. Git URL 복제 뷰
    private var gitUrlCloneView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Git Clone URL")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                TextField("https://github.com/owner/repository.git", text: $gitUrlInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("클론할 로컬 위치 (Local Clone Directory)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("경로...", text: $cloneDestInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))

                    Button("폴더 변경...") {
                        chooseCloneFolder()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Toggle("서브모듈 재귀 포함 (--recursive)", isOn: $isSubmoduleRecursive)
                .font(.system(size: 11))

            HStack(spacing: 6) {
                Circle().fill(AppTheme.activeGreen).frame(width: 6, height: 6)
                Text("디스크 여유 공간 충분")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - 푸터 액션 바
    private var footerActionBar: some View {
        HStack {
            if sourceMode == .gitHub {
                HStack(spacing: 6) {
                    Button("모두 선택") {
                        selectedIds = Set(viewModel.allFetchedRepositories.map { $0.id })
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("모두 해제") {
                        selectedIds.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            Spacer()

            Button("취소") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            switch sourceMode {
            case .localFolder:
                Button("저장소 등록") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            case .gitHub:
                Button("선택한 \(selectedIds.count)개 저장소 관리 시작") {
                    viewModel.saveSelectedRepositories(selectedIds: selectedIds)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            case .gitUrl:
                Button("복제 및 등록") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private var filteredRepos: [RepositoryItem] {
        var list = viewModel.allFetchedRepositories
        if selectedLanguageFilter != "전체" {
            if selectedLanguageFilter == "Public" {
                list = list.filter { !$0.isPrivate }
            } else if selectedLanguageFilter == "Private" {
                list = list.filter { $0.isPrivate }
            } else {
                list = list.filter { $0.language?.caseInsensitiveCompare(selectedLanguageFilter) == .orderedSame }
            }
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                ($0.description?.lowercased().contains(q) ?? false) ||
                ($0.language?.lowercased().contains(q) ?? false)
            }
        }
        return list
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "저장소 폴더 선택"

        if panel.runModal() == .OK, let url = panel.url {
            localPathInput = url.path
            localAliasInput = url.lastPathComponent
        }
    }

    private func chooseCloneFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "클론 대상 폴더 선택"

        if panel.runModal() == .OK, let url = panel.url {
            cloneDestInput = url.path
        }
    }
}
