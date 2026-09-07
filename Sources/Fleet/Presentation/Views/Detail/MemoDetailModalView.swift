import SwiftUI
import AppKit

/// Stitch Design: Fleet — Kanban Card States & Task Detail Modal
public struct MemoDetailModalView: View {
    @Binding var memo: MemoItem
    let repositoryName: String
    let defaultPreset: AppSettings.AIAgentPreset
    let onSave: (MemoItem) -> Void
    let onExecuteTask: (AppSettings.AIAgentPreset, String) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var editedStatus: MemoItem.Status
    @State private var editedPriority: MemoItem.Priority
    @State private var selectedAgent: AppSettings.AIAgentPreset
    @State private var aiPromptText: String
    @State private var checklistFilter: ChecklistFilter = .all
    @State private var newChecklistInput: String = ""
    @State private var linkedFiles: [String] = ["Sources/Fleet/Presentation", "Package.swift"]
    @State private var newFileLinkInput: String = ""
    @State private var isAddingFile = false

    public enum ChecklistFilter: String, CaseIterable, Identifiable {
        case all = "전체"
        case incomplete = "미완료만"
        public var id: String { rawValue }
    }

    public init(
        memo: Binding<MemoItem>,
        repositoryName: String,
        defaultPreset: AppSettings.AIAgentPreset,
        onSave: @escaping (MemoItem) -> Void,
        onExecuteTask: @escaping (AppSettings.AIAgentPreset, String) -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._memo = memo
        self.repositoryName = repositoryName
        self.defaultPreset = defaultPreset
        self.onSave = onSave
        self.onExecuteTask = onExecuteTask
        self.onDelete = onDelete
        self.onClose = onClose

        _editedTitle = State(initialValue: memo.wrappedValue.title)
        _editedContent = State(initialValue: memo.wrappedValue.content)
        _editedStatus = State(initialValue: memo.wrappedValue.status)
        _editedPriority = State(initialValue: memo.wrappedValue.priority)
        _selectedAgent = State(initialValue: defaultPreset)
        _aiPromptText = State(initialValue: "위 체크리스트 미완료 항목을 자동으로 구현하고 빌드 테스트를 수행해줘")
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. 헤더 (브레드크럼 & 티켓 ID & 닫기)
            headerBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // MARK: - 2. 상태, 우선순위, 담당 에이전트 뱃지 행
                    statusPriorityRow

                    // MARK: - 3. 대형 타이틀 입력
                    titleSection

                    // MARK: - 4. 작업 명세 및 체크리스트
                    checklistSection

                    // MARK: - 5. 연결된 프로젝트 소스 파일
                    linkedFilesSection

                    // MARK: - 6. AI 에이전트 CLI 오케스트레이션
                    aiOrchestrationSection
                }
                .padding(22)
            }

            Divider()

            // MARK: - 7. 하단 푸터 바 (메타데이터 및 액션 버튼)
            footerBar
        }
        .frame(width: 720, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(repositoryName) / Tasks / Detail")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("WM-\(abs(memo.id.uuidString.hashValue % 900 + 100))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06))
                .foregroundColor(.secondary)
                .clipShape(Capsule())

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var statusPriorityRow: some View {
        HStack(spacing: 10) {
            // 상태 선택기
            Menu {
                ForEach(MemoItem.Status.allCases, id: \.self) { st in
                    Button(action: { editedStatus = st }) {
                        HStack {
                            if editedStatus == st { Image(systemName: "checkmark") }
                            Text(LocalizedStringKey(st.rawValue))
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor(editedStatus))
                        .frame(width: 7, height: 7)
                    Text(LocalizedStringKey(editedStatus.rawValue))
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .opacity(0.6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor(editedStatus).opacity(0.12))
                .foregroundColor(statusColor(editedStatus))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(statusColor(editedStatus).opacity(0.3), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)

            // 우선순위 선택기
            Menu {
                ForEach(MemoItem.Priority.allCases, id: \.self) { pri in
                    Button(action: { editedPriority = pri }) {
                        HStack {
                            if editedPriority == pri { Image(systemName: "checkmark") }
                            Text(LocalizedStringKey(pri.rawValue))
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text("• \(editedPriority.rawValue)")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .opacity(0.6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(priorityColor(editedPriority).opacity(0.14))
                .foregroundColor(priorityColor(editedPriority))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(priorityColor(editedPriority).opacity(0.3), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)

            Spacer()

            // 담당 에이전트 선택
            HStack(spacing: 6) {
                Text("ASSIGNED AGENT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                Menu {
                    ForEach(AppSettings.AIAgentPreset.installedCases) { agent in
                        Button(action: { selectedAgent = agent }) {
                            Label(agent.rawValue, systemImage: agent.iconName)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: selectedAgent.iconName)
                            .font(.system(size: 11))
                            .foregroundColor(selectedAgent.brandColor)
                        Text(selectedAgent.shortName)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .opacity(0.6)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("작업 제목...", text: $editedTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
        }
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("작업 명세 및 체크리스트", systemImage: "checklist")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Picker("", selection: $checklistFilter) {
                    ForEach(ChecklistFilter.allCases) { f in
                        Text(LocalizedStringKey(f.rawValue)).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }

            // 상세 내용 편집 (자유 텍스트)
            TextEditor(text: $editedContent)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 90, maxHeight: 160)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            // 퀵 체크리스트 추가
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("새 체크리스트 항목 추가 (예: Unit Test 작성)...", text: $newChecklistInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        addChecklistItem()
                    }

                if !newChecklistInput.isEmpty {
                    Button("추가") {
                        addChecklistItem()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(6)
        }
        .padding(14)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private var linkedFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("연결된 프로젝트 소스 파일", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(linkedFiles, id: \.self) { file in
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                            Text(file)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                            Button(action: {
                                linkedFiles.removeAll { $0 == file }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.8))
                    }

                    if isAddingFile {
                        HStack(spacing: 4) {
                            TextField("파일 경로...", text: $newFileLinkInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .frame(width: 140)
                                .onSubmit {
                                    if !newFileLinkInput.trimmingCharacters(in: .whitespaces).isEmpty {
                                        linkedFiles.append(newFileLinkInput.trimmingCharacters(in: .whitespaces))
                                        newFileLinkInput = ""
                                        isAddingFile = false
                                    }
                                }
                            Button("확인") {
                                if !newFileLinkInput.trimmingCharacters(in: .whitespaces).isEmpty {
                                    linkedFiles.append(newFileLinkInput.trimmingCharacters(in: .whitespaces))
                                    newFileLinkInput = ""
                                    isAddingFile = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                        }
                        .padding(4)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                    } else {
                        Button(action: { isAddingFile = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("관련 파일 링크 추가")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private var aiOrchestrationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI 에이전트 CLI 오케스트레이션", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.activeGreen)
                        .frame(width: 6, height: 6)
                    Text("CLI Stream Ready")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.activeGreen)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.activeGreen.opacity(0.1))
                .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("실행할 AI 프롬프트 지시사항...", text: $aiPromptText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))

            Button(action: {
                var updated = memo
                updated.title = editedTitle
                updated.content = editedContent
                updated.status = .inProgress
                updated.priority = editedPriority
                updated.updatedAt = Date()
                onSave(updated)
                onExecuteTask(selectedAgent, aiPromptText)
                onClose()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                    Text("AI 프롬프트 즉시 실행 (Terminal 포커스)")
                        .font(.system(size: 12, weight: .bold))
                    Text("⌘K")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut("k", modifiers: .command)
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.04))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1))
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            Text("생성: \(memo.createdAt.formatted(date: .abbreviated, time: .shortened)) • 수정: \(memo.updatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Button("삭제", role: .destructive) {
                onDelete()
                onClose()
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.staleRose)
            .font(.system(size: 11, weight: .medium))

            Button("취소 (ESC)") {
                onClose()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("저장 및 닫기 ↵") {
                var updated = memo
                updated.title = editedTitle
                updated.content = editedContent
                updated.status = editedStatus
                updated.priority = editedPriority
                updated.updatedAt = Date()
                onSave(updated)
                onClose()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func addChecklistItem() {
        let trimmed = newChecklistInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newLine = "- [ ] \(trimmed)"
        if editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editedContent = newLine
        } else {
            editedContent += "\n" + newLine
        }
        newChecklistInput = ""
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
