import SwiftUI
import AppKit

public struct MemoTimelineView: View {
    @ObservedObject var viewModel: RepositoryDetailViewModel
    var onMemoCountChanged: ((Int) -> Void)?

    @State private var memoFilter: MemoFilter = .all
    @State private var isCreatingExpanded = false
    @FocusState private var isTitleFocused: Bool

    enum MemoFilter: String, CaseIterable, Identifiable {
        case all = "전체"
        case pending = "진행 중"
        case completed = "완료됨"

        var id: String { rawValue }
    }

    public init(viewModel: RepositoryDetailViewModel, onMemoCountChanged: ((Int) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onMemoCountChanged = onMemoCountChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - 1. 신규 메모/기능 작성 카드
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14))

                    Text("업데이트할 기능 / 아이디어 메모")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)

                    Spacer()

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
                    TextField("다음에 추가할 기능이나 버그 수정 사항을 입력하세요...", text: $viewModel.newMemoTitle)
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
                    TextField("세부 내용, 체크리스트, 참고 링크를 적어보세요 (선택사항)", text: $viewModel.newMemoContent, axis: .vertical)
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

            // MARK: - 2. 필터 헤더 및 통계
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("업데이트 백로그")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)

                    Text("\(viewModel.memos.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())

                    // 전체 선택 / 해제 퀵 토글
                    if !filteredMemos.isEmpty {
                        Button(action: {
                            let currentFilterIds = filteredMemos.map { $0.id }
                            if viewModel.selectedMemoIds.isSuperset(of: currentFilterIds) {
                                viewModel.clearSelection()
                            } else {
                                viewModel.selectAll(ids: currentFilterIds)
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: viewModel.selectedMemoIds.isSuperset(of: filteredMemos.map { $0.id }) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 11))
                                Text(viewModel.selectedMemoIds.isSuperset(of: filteredMemos.map { $0.id }) ? "전체 해제" : "전체 선택")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 6)
                    }
                }

                Spacer()

                // 완료 현황 요약
                if !viewModel.memos.isEmpty {
                    let completed = viewModel.memos.filter { $0.isCompleted }.count
                    Text("완료 \(completed)/\(viewModel.memos.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Picker("필터", selection: $memoFilter) {
                    ForEach(MemoFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }
            .padding(.top, 4)

            // MARK: - 2-1. 선택된 메모 일괄 작업 액션 바 (선택 시 동적 표시)
            if !viewModel.selectedMemoIds.isEmpty {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist.checked")
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

                    // 완료 상태 토글
                    Button(action: { Task { await viewModel.batchToggleCompletion() } }) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                            Text("완료 토글")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // 선택된 N개 항목 AI 작업수행 버튼 (기본 + 다른 AI 메뉴)
                    HStack(spacing: 2) {
                        Button(action: {
                            Task { await viewModel.executeBatchTask(preset: nil) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .bold))
                                Text("선택한 \(viewModel.selectedMemoIds.count)개 작업수행 (\(viewModel.defaultAIPreset.shortName))")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Menu {
                            Text("다른 AI 에이전트로 일괄 실행")
                                .font(.caption)

                            Divider()

                            ForEach(AppSettings.AIAgentPreset.allCases) { preset in
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
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(9)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // MARK: - 3. 메모 카드 목록
            let displayMemos = filteredMemos
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
                        Text("해당 필터에 맞는 메모가 없습니다.")
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
            return viewModel.memos.filter { !$0.isCompleted }
        case .completed:
            return viewModel.memos.filter { $0.isCompleted }
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
}

// MARK: - 모던 메모 카드 뷰
public struct ModernMemoCardView: View {
    public let memo: MemoItem
    public let isSelected: Bool
    public let defaultPreset: AppSettings.AIAgentPreset
    public let onToggleSelect: () -> Void
    public let onToggle: () -> Void
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
                // 1. AI 작업 다중 선택 체크박스
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(.top, 3)
                .help(isSelected ? "선택 해제" : "AI 작업 대상으로 선택")

                // 2. 완료 토글 버튼 (원형)
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        onToggle()
                    }
                }) {
                    Image(systemName: memo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(memo.isCompleted ? AppTheme.activeGreen : .secondary.opacity(0.7))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .help("완료 상태 토글")

                // 본문 및 타이틀
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
                                .strikethrough(memo.isCompleted, color: .secondary)
                                .foregroundColor(memo.isCompleted ? .secondary : .primary)

                            priorityPill(memo.priority)

                            statusPill(memo.status)

                            Spacer()

                            // 상대적 작성 시간
                            Text(AppTheme.relativeTimeString(from: memo.createdAt))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.8))

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
                                .lineLimit(4)
                        }
                    }
                }
            }

            // MARK: - 하단 작업수행 Action Bar
            if !isEditing {
                Divider()
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
                                Image(systemName: "sparkles")
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

                            ForEach(AppSettings.AIAgentPreset.allCases) { preset in
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
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .opacity(memo.isCompleted ? 0.78 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }

    private func priorityPill(_ priority: MemoItem.Priority) -> some View {
        Text(priority.rawValue)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(priorityColor(priority).opacity(0.12))
            .foregroundColor(priorityColor(priority))
            .clipShape(Capsule())
    }

    private func statusPill(_ status: MemoItem.Status) -> some View {
        HStack(spacing: 3) {
            Text(status.rawValue)
                .font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(statusColor(status).opacity(0.12))
        .foregroundColor(statusColor(status))
        .clipShape(Capsule())
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
}
