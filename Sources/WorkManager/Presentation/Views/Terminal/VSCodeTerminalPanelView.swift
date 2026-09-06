import SwiftUI
import AppKit
import SwiftTerm

/// SwiftTerm LocalProcessTerminalView를 SwiftUI에 임베딩하는 Representable
public struct SwiftUITerminalView: NSViewRepresentable {
    @ObservedObject var session: RepositoryTerminalSession

    public init(session: RepositoryTerminalSession) {
        self.session = session
    }

    public func makeNSView(context: Context) -> LocalProcessTerminalView {
        return session.terminalView
    }

    public func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // SwiftTerm handles internal layout and redraws
    }
}

/// VS Code 감성의 하단 내장 터미널 패널 뷰
public struct VSCodeTerminalPanelView: View {
    @ObservedObject var session: RepositoryTerminalSession
    let repository: RepositoryItem
    let localPath: String?
    let onChooseFolder: () -> Void
    let onOpenExternal: () -> Void

    @ObservedObject private var terminalManager = TerminalSessionManager.shared
    @State private var isDragging = false
    @State private var showCopiedDir = false

    public init(
        session: RepositoryTerminalSession,
        repository: RepositoryItem,
        localPath: String?,
        onChooseFolder: @escaping () -> Void,
        onOpenExternal: @escaping () -> Void
    ) {
        self.session = session
        self.repository = repository
        self.localPath = localPath
        self.onChooseFolder = onChooseFolder
        self.onOpenExternal = onOpenExternal
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. 상단 리사이즈 드래그 핸들 (VS Code 스타일)
            resizeHandle

            // MARK: - 2. VS Code 스타일 탭 & 툴바 헤더
            panelHeader

            // MARK: - 3. 로컬 폴더 미연결 경고 바 (필요 시)
            if localPath == nil {
                folderWarningBar
            }

            // MARK: - 4. SwiftTerm 터미널 본체
            SwiftUITerminalView(session: session)
                .id(session.id)
                .background(Color(nsColor: NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)))
        }
        .background(Color(nsColor: NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.12)),
            alignment: .top
        )
    }

    // MARK: - 리사이즈 핸들
    private var resizeHandle: some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.08))
            .frame(height: 4)
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
                        terminalManager.panelHeight = min(max(newHeight, 140), 560)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }

    // MARK: - 패널 헤더
    private var panelHeader: some View {
        HStack(spacing: 10) {
            // 터미널 탭 라벨 (VS Code 스타일)
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)

                Text("터미널")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)

                // 저장소 태그
                HStack(spacing: 4) {
                    Circle()
                        .fill(session.isRunning ? AppTheme.activeGreen : AppTheme.staleRose)
                        .frame(width: 6, height: 6)

                    Text(repository.name)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.06))
                .cornerRadius(4)

                // 셸 타입 뱃지
                Text("zsh")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(3)
            }

            Spacer()

            // 작업 디렉토리 표시 (클릭 시 복사)
            Button(action: {
                let path = session.workingDirectory
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
                showCopiedDir = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopiedDir = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: showCopiedDir ? "checkmark" : "folder.fill")
                        .font(.system(size: 9))
                        .foregroundColor(showCopiedDir ? AppTheme.activeGreen : .secondary)

                    Text(showCopiedDir ? "경로 복사됨!" : session.workingDirectory)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 240)
                }
            }
            .buttonStyle(.plain)
            .help("작업 디렉토리 경로 복사")

            Divider()
                .frame(height: 12)

            // 툴바 액션 버튼들
            HStack(spacing: 6) {
                // 화면 지우기 (Clear)
                headerButton(icon: "trash", tooltip: "터미널 화면 지우기 (clear)") {
                    session.clear()
                }

                // 셸 세션 재시작
                headerButton(icon: "arrow.clockwise", tooltip: "터미널 세션 재시작") {
                    session.restart()
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        terminalManager.isMaximized.toggle()
                    }
                }

                // 패널 닫기 (접기)
                headerButton(icon: "xmark", tooltip: "터미널 패널 닫기 (⌃~)") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        terminalManager.isPanelVisible = false
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.18, alpha: 1.0)))
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
