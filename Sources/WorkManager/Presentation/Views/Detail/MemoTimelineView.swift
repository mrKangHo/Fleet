import SwiftUI
import AppKit

public struct MemoTimelineView: View {
    @ObservedObject var viewModel: RepositoryDetailViewModel
    var onMemoCountChanged: ((Int) -> Void)?

    @AppStorage("workmanager_memo_view_mode") private var viewMode: MemoViewMode = .kanban
    @State private var targetedColumnStatus: MemoItem.Status? = nil
    @State private var memoFilter: MemoFilter = .all
    @State private var isCreatingExpanded = false
    @FocusState private var isTitleFocused: Bool

    public enum MemoViewMode: String, CaseIterable, Identifiable {
        case kanban = "칸반"
        case list = "리스트"

        public var id: String { rawValue }
        public var iconName: String {
            switch self {
            case .kanban: return "rectangle.split.3x1"
            case .list: return "list.bullet"
            }
        }
    }

    public enum MemoFilter: String, CaseIterable, Identifiable {
        case all = "전체"
        case pending = "대기 중"
        case inProgress = "작업 중"
        case completed = "완료됨"

        public var id: String { rawValue }
    }

    public init(viewModel: RepositoryDetailViewModel, onMemoCountChanged: ((Int) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onMemoCountChanged = onMemoCountChanged
    }

    private var allCount: Int { viewModel.memos.count }
    private var pendingCount: Int { viewModel.memos.filter { $0.status == .pending }.count }
    private var inProgressCount: Int { viewModel.memos.filter { $0.status == .inProgress }.count }
    private var completedCount: Int { viewModel.memos.filter { $0.status == .completed }.count }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - 1. 신규 메모/기능 작성 카드
            inputCard

            // MARK: - 2. 진척도 및 필터 헤더
            dashboardHeader

            // MARK: - 2-1. 선택된 메모 일괄 작업 액션 바 (선택 시 동적 표시)
            if !viewModel.selectedMemoIds.isEmpty {
                batchActionBar
            }

            // MARK: - 3. 뷰 모드에 따른 렌더링 (칸반 보드 ↔ 리스트)
            if viewMode == .kanban {
                kanbanBoard
                    .transition(.opacity)
            } else {
                memoList
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewMode)
    }

    // MARK: - Subviews
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))

                Text("새로운 작업 / 백로그 추가")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)

                Spacer()

                // 세부 메모 토글 버튼
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCreatingExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isCreatingExpanded ? "chevron.up.circle" : "text.alignleft")
                            .font(.system(size: 11))
                        Text(isCreatingExpanded ? "상세 접기" : "상세 메모")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)

                // 우선순위 칩 선택기
                Picker("우선순위", selection: $viewModel.newMemoPriority) {
                    ForEach(MemoItem.Priority.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            // 제목 입력란
            HStack(spacing: 8) {
                TextField("다음에 개발할 기능이나 수정할 버그를 입력하세요...", text: $viewModel.newMemoTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isTitleFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isTitleFocused ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .onSubmit {
                        submitNewMemo()
                    }

                Button(action: submitNewMemo) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("등록")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(viewModel.newMemoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // 상세 메모 (접이식 / 확장형)
            if isCreatingExpanded || !viewModel.newMemoTitle.isEmpty {
                TextField("상세 내용, 요구사항, 체크리스트, 참고 링크를 작성해 보세요 (선택사항)", text: $viewModel.newMemoContent, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 12)
    }

    private var dashboardHeader: some View {
        VStack(spacing: 10) {
            // 상단 타이틀 & 필터 탭
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.accentColor)

                    Text("업데이트 백로그")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)

                    Text("\(allCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())

                    // 전체 선택 / 해제 퀵 토글
                    if !filteredMemos.isEmpty {
                        let currentFilterIds = filteredMemos.map { $0.id }
                        let isAllSelected = viewModel.selectedMemoIds.isSuperset(of: currentFilterIds) && !currentFilterIds.isEmpty

                        Button(action: {
                            if isAllSelected {
                                viewModel.clearSelection()
                            } else {
                                viewModel.selectAll(ids: currentFilterIds)
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: isAllSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                Text(isAllSelected ? "전체 해제" : "전체 선택")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 6)
                    }
                }

                Spacer()

                // 리스트 모드일 때만 4-단계 세그먼트 필터 표시
                if viewMode == .list {
                    Picker("필터", selection: $memoFilter) {
                        Text("전체 (\(allCount))").tag(MemoFilter.all)
                        Text("대기 (\(pendingCount))").tag(MemoFilter.pending)
                        Text("작업 중 (\(inProgressCount))").tag(MemoFilter.inProgress)
                        Text("완료 (\(completedCount))").tag(MemoFilter.completed)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                    .transition(.opacity)
                }

                // 뷰 모드 세그먼트 전환기 (칸반 보드 ↔ 리스트)
                Picker("보기", selection: $viewMode) {
                    ForEach(MemoViewMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            // 진척도 진행 바
            if allCount > 0 {
                let progress = Double(completedCount) / Double(allCount)
                let percent = Int(progress * 100)

                HStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 6)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: completedCount == allCount
                                            ? [AppTheme.activeGreen, AppTheme.activeGreen.opacity(0.85)]
                                            : [Color.accentColor, Color.accentColor.opacity(0.75)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 6)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: progress)
                        }
                    }
                    .frame(height: 6)

                    Text("\(completedCount)/\(allCount) 완료 (\(percent)%)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(completedCount == allCount ? AppTheme.activeGreen : .secondary)
                        .frame(width: 105, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(6)
            }
        }
        .padding(.top, 4)
    }

    private var batchActionBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13, weight: .bold))

                Text("\(viewModel.selectedMemoIds.count)개 메모 선택됨")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()

            // 선택 해제
            Button("선택 해제") {
                viewModel.clearSelection()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            // 통합 프롬프트 복사
            Button(action: { viewModel.copyBatchPrompt() }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                    Text("통합 프롬프트 복사")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // 일괄 상태 변경 메뉴
            Menu {
                Text("선택 항목 상태 일괄 변경")
                    .font(.caption)

                Divider()

                Button(action: { Task { await viewModel.batchUpdateStatus(.pending) } }) {
                    Label("대기 중으로 변경", systemImage: "circle.dashed")
                }

                Button(action: { Task { await viewModel.batchUpdateStatus(.inProgress) } }) {
                    Label("작업 중으로 변경", systemImage: "bolt.fill")
                }

                Button(action: { Task { await viewModel.batchUpdateStatus(.completed) } }) {
                    Label("완료됨으로 변경", systemImage: "checkmark.circle.fill")
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("상태 변경")
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.bordered)
            .controlSize(.small)

            // 일괄 삭제
            Button(action: {
                Task {
                    let newCount = await viewModel.batchDeleteSelectedMemos()
                    onMemoCountChanged?(newCount)
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                    Text("삭제")
                        .font(.system(size: 11))
                }
                .foregroundColor(AppTheme.staleRose)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // 선택된 N개 항목 AI 작업수행 버튼
            HStack(spacing: 2) {
                Button(action: {
                    Task { await viewModel.executeBatchTask(preset: nil) }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.defaultAIPreset.iconName)
                            .font(.system(size: 11, weight: .bold))
                        Text("일괄 실행 (\(viewModel.defaultAIPreset.shortName))")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Menu {
                    Text("다른 AI 에이전트로 일괄 실행")
                        .font(.caption)

                    Divider()

                    ForEach(availablePresets(defaultPreset: viewModel.defaultAIPreset)) { preset in
                        Button(action: {
                            Task { await viewModel.executeBatchTask(preset: preset) }
                        }) {
                            Label(
                                preset == viewModel.defaultAIPreset ? "\(preset.rawValue) (기본)" : preset.rawValue,
                                systemImage: preset.iconName
                            )
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 2)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("다른 AI 에이전트 선택")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var memoList: some View {
        let displayMemos = filteredMemos
        return Group {
            if displayMemos.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 24)
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 42))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.accentColor.opacity(0.7))

                    if viewModel.memos.isEmpty {
                        Text("등록된 업데이트 메모가 없습니다")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.primary)
                        Text("위 입력창에 다음에 개발할 기능이나 수정할 버그를 적어두면 잊지 않고 작업할 수 있습니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 340)
                    } else {
                        Text("선택한 '\(memoFilter.rawValue)' 필터에 해당하는 메모가 없습니다.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .glassCard(cornerRadius: 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(displayMemos) { memo in
                        let isSelected = viewModel.selectedMemoIds.contains(memo.id)
                        ModernMemoCardView(
                            memo: memo,
                            isSelected: isSelected,
                            defaultPreset: viewModel.defaultAIPreset,
                            onToggleSelect: {
                                viewModel.toggleMemoSelection(id: memo.id)
                            },
                            onToggle: {
                                Task { await viewModel.toggleCompletion(for: memo) }
                            },
                            onUpdateStatus: { newStatus in
                                Task { await viewModel.updateMemoStatus(for: memo, newStatus: newStatus) }
                            },
                            onUpdatePriority: { newPriority in
                                Task { await viewModel.updateMemoPriority(for: memo, newPriority: newPriority) }
                            },
                            onUpdate: { updatedMemo in
                                Task { await viewModel.updateMemo(updatedMemo) }
                            },
                            onExecuteTask: { chosenPreset in
                                Task { await viewModel.executeTask(for: memo, preset: chosenPreset) }
                            },
                            onCopyPrompt: {
                                viewModel.copyPrompt(for: memo)
                            },
                            onDelete: {
                                Task {
                                    let newCount = await viewModel.deleteMemo(id: memo.id)
                                    onMemoCountChanged?(newCount)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var filteredMemos: [MemoItem] {
        switch memoFilter {
        case .all:
            return viewModel.memos
        case .pending:
            return viewModel.memos.filter { $0.status == .pending }
        case .inProgress:
            return viewModel.memos.filter { $0.status == .inProgress }
        case .completed:
            return viewModel.memos.filter { $0.status == .completed }
        }
    }

    private func submitNewMemo() {
        guard !viewModel.newMemoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            let newCount = await viewModel.addMemo()
            onMemoCountChanged?(newCount)
            isTitleFocused = false
        }
    }

    // MARK: - 3-1. 칸반 보드 뷰 (Linear Style 3-Column Pipeline)
    private var kanbanBoard: some View {
        Group {
            if viewModel.memos.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 28)
                    Image(systemName: "rectangle.split.3x1")
                        .font(.system(size: 42))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.accentColor.opacity(0.7))

                    Text("등록된 업데이트 백로그가 없습니다")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                    Text("상단 입력창에서 새로운 기능이나 수정할 버그를 등록하면\n칸반 파이프라인에서 시각적으로 관리할 수 있습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                    Spacer(minLength: 28)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassCard(cornerRadius: 12)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    // 1. 대기 중 컬럼
                    kanbanColumn(
                        title: "대기 중",
                        status: .pending,
                        icon: "circle.dashed",
                        iconColor: .secondary,
                        badgeBg: Color.secondary.opacity(0.12),
                        memos: viewModel.memos.filter { $0.status == .pending }
                    )

                    // 2. 작업 중 🚀 컬럼
                    kanbanColumn(
                        title: "작업 중 🚀",
                        status: .inProgress,
                        icon: "bolt.fill",
                        iconColor: .orange,
                        badgeBg: Color.orange.opacity(0.16),
                        memos: viewModel.memos.filter { $0.status == .inProgress }
                    )

                    // 3. 완료됨 컬럼
                    kanbanColumn(
                        title: "완료됨",
                        status: .completed,
                        icon: "checkmark.circle.fill",
                        iconColor: AppTheme.activeGreen,
                        badgeBg: AppTheme.activeGreen.opacity(0.16),
                        memos: viewModel.memos.filter { $0.status == .completed }
                    )
                }
                .frame(minHeight: 380)
            }
        }
    }

    private func kanbanColumn(
        title: String,
        status: MemoItem.Status,
        icon: String,
        iconColor: Color,
        badgeBg: Color,
        memos: [MemoItem]
    ) -> some View {
        let isDropTargeted = targetedColumnStatus == status

        return VStack(alignment: .leading, spacing: 10) {
            // 컬럼 헤더
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("\(memos.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeBg)
                    .foregroundColor(iconColor)
                    .clipShape(Capsule())

                Spacer()

                if status == .pending {
                    Button(action: {
                        isTitleFocused = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("새 작업 입력란으로 포커스 이동")
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            // 카드 리스트
            if memos.isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 24)
                    Image(systemName: emptyIcon(for: status))
                        .font(.system(size: 24))
                        .foregroundColor(iconColor.opacity(0.35))
                    Text(emptyText(for: status))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 9) {
                        ForEach(memos) { memo in
                            let isSelected = viewModel.selectedMemoIds.contains(memo.id)
                            KanbanMemoCardView(
                                memo: memo,
                                isSelected: isSelected,
                                defaultPreset: viewModel.defaultAIPreset,
                                onToggleSelect: { viewModel.toggleMemoSelection(id: memo.id) },
                                onToggle: { Task { await viewModel.toggleCompletion(for: memo) } },
                                onUpdateStatus: { newStatus in Task { await viewModel.updateMemoStatus(for: memo, newStatus: newStatus) } },
                                onUpdatePriority: { newPriority in Task { await viewModel.updateMemoPriority(for: memo, newPriority: newPriority) } },
                                onUpdate: { updated in Task { await viewModel.updateMemo(updated) } },
                                onExecuteTask: { preset in Task { await viewModel.executeTask(for: memo, preset: preset) } },
                                onCopyPrompt: { viewModel.copyPrompt(for: memo) },
                                onDelete: {
                                    Task {
                                        let newCount = await viewModel.deleteMemo(id: memo.id)
                                        onMemoCountChanged?(newCount)
                                    }
                                }
                            )
                            .draggable(memo.id.uuidString)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDropTargeted ? iconColor.opacity(0.08) : Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? iconColor.opacity(0.6) : (status == .inProgress && !memos.isEmpty ? Color.orange.opacity(0.25) : Color.primary.opacity(0.06)),
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
        )
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first, let uuid = UUID(uuidString: first) else { return false }
            if let targetMemo = viewModel.memos.first(where: { $0.id == uuid }) {
                if targetMemo.status != status {
                    Task { await viewModel.updateMemoStatus(for: targetMemo, newStatus: status) }
                }
                return true
            }
            return false
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.targetedColumnStatus = targeted ? status : nil
            }
        }
    }

    private func emptyIcon(for status: MemoItem.Status) -> String {
        switch status {
        case .pending: return "tray"
        case .inProgress: return "bolt.slash"
        case .completed: return "checkmark.circle"
        }
    }

    private func emptyText(for status: MemoItem.Status) -> String {
        switch status {
        case .pending: return "대기 중인 작업이 없습니다"
        case .inProgress: return "진행 중인 작업이 없습니다"
        case .completed: return "완료된 작업이 없습니다"
        }
    }

    private func availablePresets(defaultPreset: AppSettings.AIAgentPreset) -> [AppSettings.AIAgentPreset] {
        var list = AppSettings.AIAgentPreset.installedCases
        if defaultPreset == .custom && !list.contains(.custom) {
            list.append(.custom)
        }
        return list
    }
}

// MARK: - 모던 메모 카드 뷰 (Apple HIG & UI UX Pro Max)
public struct ModernMemoCardView: View {
    public let memo: MemoItem
    public let isSelected: Bool
    public let defaultPreset: AppSettings.AIAgentPreset
    public let onToggleSelect: () -> Void
    public let onToggle: () -> Void
    public let onUpdateStatus: (MemoItem.Status) -> Void
    public let onUpdatePriority: (MemoItem.Priority) -> Void
    public let onUpdate: (MemoItem) -> Void
    public let onExecuteTask: (AppSettings.AIAgentPreset?) -> Void
    public let onCopyPrompt: () -> Void
    public let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedContent = ""

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                // 1. 단일 원형 완료 체크 버튼 (Apple Reminders 스타일)
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        onToggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(memo.isCompleted ? AppTheme.activeGreen : Color.secondary.opacity(0.35), lineWidth: 1.5)
                            .frame(width: 18, height: 18)

                        if memo.isCompleted {
                            Circle()
                                .fill(AppTheme.activeGreen)
                                .frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .help(memo.isCompleted ? "미완료 상태로 변경" : "완료 상태로 변경")

                // 2. 본문 및 헤더
                if isEditing {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("제목 수정", text: $editedTitle)
                            .textFieldStyle(.roundedBorder)
                        TextField("내용 수정", text: $editedContent, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)

                        HStack {
                            Button("저장") {
                                var updated = memo
                                updated.title = editedTitle
                                updated.content = editedContent
                                onUpdate(updated)
                                isEditing = false
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("취소") {
                                isEditing = false
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(memo.title)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .strikethrough(memo.isCompleted, color: .secondary.opacity(0.7))
                                .foregroundColor(memo.isCompleted ? .secondary : .primary)

                            // 대화형 상태 뱃지 (클릭 시 상태 전환 메뉴)
                            interactiveStatusMenu(memo.status)

                            // 대화형 우선순위 뱃지 (클릭 시 우선순위 전환 메뉴)
                            interactivePriorityMenu(memo.priority)

                            Spacer()

                            // 상대적 작성 시간
                            Text(AppTheme.relativeTimeString(from: memo.createdAt))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))

                            // 액션 버튼 그룹 (편집, 삭제)
                            if isHovered {
                                HStack(spacing: 6) {
                                    Button(action: {
                                        editedTitle = memo.title
                                        editedContent = memo.content
                                        isEditing = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("수정")

                                    Button(action: onDelete) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.staleRose)
                                    }
                                    .buttonStyle(.plain)
                                    .help("삭제")
                                }
                                .transition(.opacity)
                            }
                        }

                        if !memo.content.isEmpty {
                            Text(memo.content)
                                .font(.system(size: 12))
                                .foregroundColor(memo.isCompleted ? .secondary.opacity(0.6) : .secondary)
                                .lineLimit(isHovered ? 8 : 3)
                        }
                    }
                }
            }

            // MARK: - 하단 작업수행 Action Bar
            if !isEditing {
                Divider()
                    .opacity(0.4)
                    .padding(.top, 2)

                HStack(spacing: 8) {
                    if let lastExec = memo.lastExecutedAt {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text("최근 실행: \(AppTheme.relativeTimeString(from: lastExec))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // AI 일괄선택 토글 캡슐 버튼 (완료 체크와 완전히 분리)
                    Button(action: onToggleSelect) {
                        HStack(spacing: 4) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "sparkles")
                                .font(.system(size: 10))
                            Text(isSelected ? "선택됨" : "AI 일괄선택")
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.1), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(isSelected ? "선택 해제" : "여러 작업을 한 번에 AI로 실행하기 위해 선택")

                    // 프롬프트 복사 버튼
                    Button(action: onCopyPrompt) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("프롬프트 복사")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // 작업수행 AI 버튼 및 다른 AI 선택 분할 메뉴
                    HStack(spacing: 2) {
                        // 1. 기본 AI로 즉시 실행
                        Button(action: { onExecuteTask(nil) }) {
                            HStack(spacing: 4) {
                                Image(systemName: defaultPreset.iconName)
                                    .font(.system(size: 11, weight: .bold))
                                Text("작업수행 (\(defaultPreset.shortName))")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        // 2. 다른 AI 에이전트 선택 드롭다운 메뉴
                        Menu {
                            Text("다른 AI 에이전트로 실행")
                                .font(.caption)

                            Divider()

                            ForEach(availablePresets) { preset in
                                Button(action: {
                                    onExecuteTask(preset)
                                }) {
                                    Label(
                                        preset == defaultPreset ? "\(preset.rawValue) (기본)" : preset.rawValue,
                                        systemImage: preset.iconName
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 2)
                        }
                        .menuStyle(.borderlessButton)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .help("다른 AI 에이전트 선택")
                    }
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 10, isHovered: isHovered)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .opacity(memo.isCompleted ? 0.76 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }

    private func interactiveStatusMenu(_ currentStatus: MemoItem.Status) -> some View {
        Menu {
            Text("상태 변경")
                .font(.caption)

            Divider()

            ForEach(MemoItem.Status.allCases, id: \.self) { st in
                Button(action: {
                    onUpdateStatus(st)
                }) {
                    HStack {
                        if st == currentStatus {
                            Image(systemName: "checkmark")
                        }
                        Text(st.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Circle()
                    .fill(statusColor(currentStatus))
                    .frame(width: 5, height: 5)
                Text(currentStatus.rawValue)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .opacity(0.5)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(statusColor(currentStatus).opacity(0.12))
            .foregroundColor(statusColor(currentStatus))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(statusColor(currentStatus).opacity(0.28), lineWidth: 0.6)
            )
        }
        .menuStyle(.borderlessButton)
        .help("클릭하여 작업 상태 변경")
    }

    private func interactivePriorityMenu(_ currentPriority: MemoItem.Priority) -> some View {
        Menu {
            Text("우선순위 변경")
                .font(.caption)

            Divider()

            ForEach(MemoItem.Priority.allCases, id: \.self) { pri in
                Button(action: {
                    onUpdatePriority(pri)
                }) {
                    HStack {
                        if pri == currentPriority {
                            Image(systemName: "checkmark")
                        }
                        Text(pri.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(currentPriority.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .opacity(0.5)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(priorityColor(currentPriority).opacity(0.14))
            .foregroundColor(priorityColor(currentPriority))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(priorityColor(currentPriority).opacity(0.28), lineWidth: 0.6)
            )
        }
        .menuStyle(.borderlessButton)
        .help("클릭하여 우선순위 변경")
    }

    private func statusColor(_ status: MemoItem.Status) -> Color {
        switch status {
        case .pending: return .secondary
        case .inProgress: return .orange
        case .completed: return AppTheme.activeGreen
        }
    }

    private func priorityColor(_ priority: MemoItem.Priority) -> Color {
        switch priority {
        case .high: return AppTheme.staleRose
        case .medium: return AppTheme.warningAmber
        case .low: return Color.blue
        }
    }

    private var availablePresets: [AppSettings.AIAgentPreset] {
        var list = AppSettings.AIAgentPreset.installedCases
        if defaultPreset == .custom && !list.contains(.custom) {
            list.append(.custom)
        }
        return list
    }
}

// MARK: - 칸반 전용 모던 메모 카드 뷰 (Linear Style)
public struct KanbanMemoCardView: View {
    public let memo: MemoItem
    public let isSelected: Bool
    public let defaultPreset: AppSettings.AIAgentPreset
    public let onToggleSelect: () -> Void
    public let onToggle: () -> Void
    public let onUpdateStatus: (MemoItem.Status) -> Void
    public let onUpdatePriority: (MemoItem.Priority) -> Void
    public let onUpdate: (MemoItem) -> Void
    public let onExecuteTask: (AppSettings.AIAgentPreset?) -> Void
    public let onCopyPrompt: () -> Void
    public let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedContent = ""

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 1. 헤더 (원형 체크 + 우선순위 메뉴 + 시간 + 수정/삭제)
            HStack(spacing: 6) {
                // 단일 원형 완료 체크 버튼
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        onToggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(memo.isCompleted ? AppTheme.activeGreen : Color.secondary.opacity(0.35), lineWidth: 1.4)
                            .frame(width: 16, height: 16)

                        if memo.isCompleted {
                            Circle()
                                .fill(AppTheme.activeGreen)
                                .frame(width: 16, height: 16)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(memo.isCompleted ? "미완료 상태로 변경" : "완료 상태로 변경")

                // 대화형 우선순위 뱃지
                priorityMenu(memo.priority)

                Spacer()

                Text(AppTheme.relativeTimeString(from: memo.createdAt))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))

                if isHovered {
                    HStack(spacing: 4) {
                        Button(action: {
                            editedTitle = memo.title
                            editedContent = memo.content
                            isEditing = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("수정")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.staleRose)
                        }
                        .buttonStyle(.plain)
                        .help("삭제")
                    }
                    .transition(.opacity)
                }
            }

            // 2. 카드 본문 (제목 & 내용)
            if isEditing {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("제목", text: $editedTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    TextField("내용", text: $editedContent, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .lineLimit(2...4)

                    HStack {
                        Button("저장") {
                            var updated = memo
                            updated.title = editedTitle
                            updated.content = editedContent
                            onUpdate(updated)
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)

                        Button("취소") {
                            isEditing = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(memo.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .strikethrough(memo.isCompleted, color: .secondary.opacity(0.7))
                        .foregroundColor(memo.isCompleted ? .secondary : .primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !memo.content.isEmpty {
                        Text(memo.content)
                            .font(.system(size: 11))
                            .foregroundColor(memo.isCompleted ? .secondary.opacity(0.6) : .secondary)
                            .lineLimit(3)
                    }
                }
            }

            // 3. 카드 하단 메타 및 액션 바
            if !isEditing {
                Divider()
                    .opacity(0.3)
                    .padding(.top, 1)

                HStack(spacing: 6) {
                    // 최근 실행 인디케이터
                    if let lastExec = memo.lastExecutedAt {
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                            Text(AppTheme.relativeTimeString(from: lastExec))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // AI 일괄선택 토글 캡슐
                    Button(action: onToggleSelect) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(3)
                    .background(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                    .clipShape(Circle())
                    .help(isSelected ? "선택 해제" : "AI 일괄 작업 대상 선택")

                    // 프롬프트 복사
                    Button(action: onCopyPrompt) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(3)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Circle())
                    .help("AI 프롬프트 복사")

                    // 상태별 핵심 동작 버튼
                    quickActionButton
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.16) : Color.primary.opacity(0.08)),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 5 : 2, y: isHovered ? 2 : 1)
        .opacity(memo.isCompleted ? 0.75 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }

    // 상태에 따른 퀵 액션 버튼
    @ViewBuilder
    private var quickActionButton: some View {
        switch memo.status {
        case .pending:
            // 대기 중: 즉시 AI 실행 분할 버튼
            HStack(spacing: 1) {
                Button(action: { onExecuteTask(nil) }) {
                    HStack(spacing: 3) {
                        Image(systemName: defaultPreset.iconName)
                            .font(.system(size: 9, weight: .bold))
                        Text(defaultPreset.shortName)
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)

                Menu {
                    Text("다른 AI 에이전트로 실행").font(.caption)
                    Divider()
                    ForEach(availablePresets) { preset in
                        Button(action: { onExecuteTask(preset) }) {
                            Label(preset == defaultPreset ? "\(preset.rawValue) (기본)" : preset.rawValue, systemImage: preset.iconName)
                        }
                    }
                    Divider()
                    Button(action: { onUpdateStatus(.inProgress) }) {
                        Label("작업 중으로 이동 (실행 없이)", systemImage: "bolt.fill")
                    }
                    Button(action: { onUpdateStatus(.completed) }) {
                        Label("완료로 이동", systemImage: "checkmark.circle.fill")
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 1)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            }

        case .inProgress:
            // 작업 중: 완료하기 버튼 + 메뉴
            HStack(spacing: 2) {
                Button(action: { onUpdateStatus(.completed) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("완료")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(AppTheme.activeGreen)

                Menu {
                    Button(action: { onExecuteTask(nil) }) {
                        Label("\(defaultPreset.shortName)로 재실행", systemImage: defaultPreset.iconName)
                    }
                    Button(action: { onUpdateStatus(.pending) }) {
                        Label("대기 중으로 되돌리기", systemImage: "circle.dashed")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 9))
                        .padding(.horizontal, 2)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

        case .completed:
            // 완료됨: 되돌리기 버튼
            Button(action: { onUpdateStatus(.pending) }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 8))
                    Text("대기")
                        .font(.system(size: 9))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
    }

    private func priorityMenu(_ currentPriority: MemoItem.Priority) -> some View {
        Menu {
            Text("우선순위 변경").font(.caption)
            Divider()
            ForEach(MemoItem.Priority.allCases, id: \.self) { pri in
                Button(action: { onUpdatePriority(pri) }) {
                    HStack {
                        if pri == currentPriority { Image(systemName: "checkmark") }
                        Text(pri.rawValue)
                    }
                }
            }
        } label: {
            Text(currentPriority.rawValue)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(priorityColor(currentPriority).opacity(0.14))
                .foregroundColor(priorityColor(currentPriority))
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .help("우선순위 변경")
    }

    private func priorityColor(_ priority: MemoItem.Priority) -> Color {
        switch priority {
        case .high: return AppTheme.staleRose
        case .medium: return AppTheme.warningAmber
        case .low: return Color.blue
        }
    }

    private var availablePresets: [AppSettings.AIAgentPreset] {
        var list = AppSettings.AIAgentPreset.installedCases
        if defaultPreset == .custom && !list.contains(.custom) {
            list.append(.custom)
        }
        return list
    }
}
