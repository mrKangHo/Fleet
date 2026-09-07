import SwiftUI
import AppKit
import SwiftTerm

/// SwiftTerm LocalProcessTerminalView를 SwiftUI에 임베딩하는 Representable
public struct SwiftUITerminalView: NSViewRepresentable {
    @ObservedObject var tab: TerminalTabItem

    public init(tab: TerminalTabItem) {
        self.tab = tab
    }

    public func makeNSView(context: Context) -> LocalProcessTerminalView {
        return tab.terminalView
    }

    public func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // SwiftTerm handles internal layout and redraws
    }
}

/// VS Code & Apple HIG 감성의 하단 내장 다중 탭 터미널 패널 뷰
public struct VSCodeTerminalPanelView: View {
    @ObservedObject var group: RepositoryTerminalGroup
    let repository: RepositoryItem
    let localPath: String?
    let onChooseFolder: () -> Void
    let onOpenExternal: () -> Void

    @ObservedObject private var terminalManager = TerminalSessionManager.shared
    @State private var isDragging = false
    @State private var showCopiedDir = false
    @State private var hoveredTabId: UUID? = nil

    public init(
        group: RepositoryTerminalGroup,
        repository: RepositoryItem,
        localPath: String?,
        onChooseFolder: @escaping () -> Void,
        onOpenExternal: @escaping () -> Void
    ) {
        self.group = group
        self.repository = repository
        self.localPath = localPath
        self.onChooseFolder = onChooseFolder
        self.onOpenExternal = onOpenExternal
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. 상단 리사이즈 드래그 핸들
            resizeHandle

            // MARK: - 2. 다중 탭 & 툴바 헤더 (Apple HIG 고대비 적응형 스타일)
            panelHeader

            // MARK: - 3. 로컬 폴더 미연결 경고 바 (필요 시)
            if localPath == nil {
                folderWarningBar
            }

            // MARK: - 4. SwiftTerm 터미널 본체 (활성 탭 렌더링)
            if let activeTab = group.activeTab {
                SwiftUITerminalView(tab: activeTab)
                    .id(activeTab.id)
                    .background(Color(nsColor: activeTab.terminalView.nativeBackgroundColor))
            } else {
                emptyTabsPlaceholder
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .top
        )
    }

    // MARK: - 리사이즈 핸들
    private var resizeHandle: some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor : Color(nsColor: .separatorColor))
            .frame(height: 3)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        let newHeight = terminalManager.panelHeight - value.translation.height
                        terminalManager.panelHeight = min(max(newHeight, 140), 620)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }

    // MARK: - 패널 헤더 (다중 탭 바 + 툴바 액션)
    private var panelHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // 좌측: 탭 리스트 (가로 스크롤 가능)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(group.tabs) { tab in
                            tabPill(for: tab)
                        }

                        // 새 터미널 탭 추가 버튼 (+)
                        newTabMenuButton
                    }
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 8)

                // 우측: 작업 디렉토리 경로 (클릭 시 복사)
                Button(action: {
                    let path = group.workingDirectory
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                    showCopiedDir = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopiedDir = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: showCopiedDir ? "checkmark" : "folder.fill")
                            .font(.system(size: 9))
                            .foregroundColor(showCopiedDir ? AppTheme.activeGreen : .accentColor)

                        Text(showCopiedDir ? "경로 복사됨!" : group.workingDirectory)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(showCopiedDir ? AppTheme.activeGreen : .primary.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 220)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .help("작업 디렉토리 경로 복사")

                Divider()
                    .frame(height: 14)

                // 툴바 액션 버튼들 (고대비 명확한 시인성)
                HStack(spacing: 5) {
                    // 화면 지우기 (Clear)
                    headerButton(icon: "trash", tooltip: "터미널 화면 지우기 (clear)") {
                        group.activeTab?.clear()
                    }

                    // 셸 세션 재시작
                    headerButton(icon: "arrow.clockwise", tooltip: "현재 터미널 재시작") {
                        group.activeTab?.restart()
                    }

                    // 외부 터미널 앱으로 열기
                    headerButton(icon: "arrow.up.forward.app", tooltip: "macOS 외부 터미널로 열기") {
                        onOpenExternal()
                    }

                    // 최대화 토글
                    headerButton(
                        icon: terminalManager.isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                        tooltip: terminalManager.isMaximized ? "패널 크기 원래대로" : "패널 최대화"
                    ) {
                        withAnimation(AppTheme.fluidSpring) {
                            terminalManager.isMaximized.toggle()
                        }
                    }

                    // 패널 닫기 (접기)
                    headerButton(icon: "xmark", tooltip: "터미널 패널 닫기 (⌃~)") {
                        withAnimation(AppTheme.fluidSpring) {
                            terminalManager.isPanelVisible = false
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(nsColor: .windowBackgroundColor))

            // 툴바와 터미널 본체 사이의 뚜렷한 경계선
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor))
        }
    }

    // MARK: - 개별 탭 버튼 (Apple Pro Max Tab Pill)
    private func tabPill(for tab: TerminalTabItem) -> some View {
        let isActive = group.activeTabId == tab.id
        let isHovered = hoveredTabId == tab.id
        let brandColor = tab.preset?.brandColor ?? Color.accentColor

        return Button(action: {
            withAnimation(AppTheme.quickSpring) {
                group.selectTab(id: tab.id)
            }
        }) {
            HStack(spacing: 6) {
                // 에이전트 / 셸 고유 아이콘
                Image(systemName: tab.preset?.iconName ?? "terminal.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(brandColor)

                // 탭 이름 (명확한 고대비 가독성)
                Text(tab.title)
                    .font(.system(size: 11, weight: isActive ? .bold : .medium, design: .rounded))
                    .foregroundColor(isActive ? .primary : .secondary)

                // 실행 상태 인디케이터 (초록 발광 점 또는 종료 표시)
                if tab.isRunning {
                    Circle()
                        .fill(AppTheme.activeGreen)
                        .frame(width: 6, height: 6)
                        .shadow(color: AppTheme.activeGreen.opacity(0.8), radius: 2)
                } else if let code = tab.exitCode, code != 0 {
                    Circle()
                        .fill(AppTheme.staleRose)
                        .frame(width: 6, height: 6)
                }

                // 탭 닫기 버튼 (✕)
                Button(action: {
                    withAnimation(AppTheme.quickSpring) {
                        group.closeTab(id: tab.id)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isActive ? .primary.opacity(0.7) : .secondary)
                        .frame(width: 16, height: 16)
                        .background(Color.primary.opacity(isHovered || isActive ? 0.08 : 0.0))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("탭 닫기")
                .opacity(isActive || isHovered || group.tabs.count > 1 ? 1.0 : 0.0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                isActive
                    ? Color(nsColor: .controlBackgroundColor)
                    : (isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isActive
                            ? brandColor.opacity(0.7)
                            : (isHovered ? Color.primary.opacity(0.14) : Color.primary.opacity(0.06)),
                        lineWidth: isActive ? 1.2 : 0.6
                    )
            )
            .shadow(color: Color.black.opacity(isActive ? 0.06 : 0.0), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredTabId = hovering ? tab.id : nil
        }
    }

    // MARK: - 새 탭 생성 (+) 분할 메뉴 버튼
    private var newTabMenuButton: some View {
        Menu {
            Button(action: {
                withAnimation(AppTheme.quickSpring) {
                    _ = group.createTab(preset: nil, autoSelect: true)
                }
            }) {
                Label("새 터미널 (기본 zsh)", systemImage: "terminal.fill")
            }

            Divider()

            Text("새 AI 에이전트 탭:")
                .font(.caption)

            ForEach(AppSettings.AIAgentPreset.allCases) { preset in
                Button(action: {
                    withAnimation(AppTheme.quickSpring) {
                        _ = group.createTab(preset: preset, autoSelect: true)
                    }
                }) {
                    Label(preset.rawValue, systemImage: preset.iconName)
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.primary.opacity(0.85))
                .frame(width: 24, height: 24)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8)
                )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("새 터미널 탭 추가")
    }

    // MARK: - 탭이 없는 경우의 플레이스홀더
    private var emptyTabsPlaceholder: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.5))
            Text("열려있는 터미널 탭이 없습니다.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("새 터미널 열기") {
                _ = group.createTab()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 로컬 폴더 미연결 경고 바
    private var folderWarningBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.warningAmber)
                .font(.system(size: 11))

            Text("로컬 저장소 폴더가 지정되지 않아 기본 홈 디렉토리(\(FileManager.default.homeDirectoryForCurrentUser.path))에서 실행 중입니다.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Button("로컬 폴더 연결") {
                onChooseFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(AppTheme.warningAmber.opacity(0.12))
    }

    private func headerButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary.opacity(0.85))
                .frame(width: 24, height: 24)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
