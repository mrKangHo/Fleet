import SwiftUI
import AppKit

public struct RepositoryDetailView: View {
    @ObservedObject var viewModel: RepositoryDetailViewModel
    var onMemoCountChanged: ((Int) -> Void)?

    @ObservedObject private var terminalManager = TerminalSessionManager.shared
    @AppStorage("workmanager_file_tree_visible") private var isFileTreeVisible: Bool = true
    @AppStorage("workmanager_file_tree_width") private var fileTreeWidth: Double = 270.0

    public init(viewModel: RepositoryDetailViewModel, onMemoCountChanged: ((Int) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onMemoCountChanged = onMemoCountChanged
    }

    public var body: some View {
        Group {
            if let repo = viewModel.repository {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // MARK: - 1. 슬림하고 정돈된 저장소 헤더 바
                        repositoryHeaderBar(for: repo)

                        // MARK: - 2. 알림 및 피드백 배너 (성공/오류 발생 시 표시)
                        if let success = viewModel.successMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.activeGreen)
                                Text(success)
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Button(action: { viewModel.successMessage = nil }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(AppTheme.activeGreen.opacity(0.12))
                        }

                        if let error = viewModel.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.staleRose)
                                Text(error)
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Button(action: { viewModel.errorMessage = nil }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(AppTheme.staleRose.opacity(0.12))
                        }

                        // MARK: - 3. 메인 포커스: 메모 및 칸반 보드 (전체 높이 확장)
                        MemoTimelineView(
                            viewModel: viewModel,
                            onMemoCountChanged: onMemoCountChanged
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // MARK: - VS Code 스타일 하단 터미널 패널
                    if terminalManager.isPanelVisible {
                        let group = terminalManager.getOrCreateGroup(
                            for: repo.id,
                            name: repo.name,
                            localPath: viewModel.localDirectoryPath
                        )
                        VSCodeTerminalPanelView(
                            group: group,
                            repository: repo,
                            localPath: viewModel.localDirectoryPath,
                            onChooseFolder: { viewModel.chooseLocalFolder() },
                            onOpenExternal: { viewModel.openInExternalTerminal() }
                        )
                        .frame(height: terminalManager.isMaximized ? 480 : terminalManager.panelHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // MARK: - VS Code 스타일 하단 상태 바
                    bottomStatusBar(for: repo)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MARK: - 오른쪽 로컬 작업 디렉토리 파일 트리 사이드바
                if isFileTreeVisible {
                    FileTreeSidebarView(
                        rootPath: viewModel.localDirectoryPath,
                        sidebarWidth: $fileTreeWidth,
                        onChooseFolder: { viewModel.chooseLocalFolder() },
                        onOpenFile: { url in
                            NSWorkspace.shared.open(url)
                        },
                        onRevealInFinder: { url in
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        },
                        onOpenInTerminal: { targetPath in
                            if !terminalManager.isPanelVisible {
                                terminalManager.togglePanel(for: repo.id, name: repo.name, localPath: viewModel.localDirectoryPath)
                            }
                            let grp = terminalManager.getOrCreateGroup(for: repo.id, name: repo.name, localPath: viewModel.localDirectoryPath)
                            if let activeTab = grp.activeTab {
                                var isDir: ObjCBool = false
                                let exists = FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir)
                                let dirPath = (exists && isDir.boolValue) ? targetPath : (targetPath as NSString).deletingLastPathComponent
                                activeTab.sendCommand("cd \"\(dirPath)\"\n")
                            }
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isFileTreeVisible = false
                            }
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
                    // Empty State (저장소 미선택)
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 54))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.accentColor.opacity(0.6))

                        Text("저장소를 선택해 주세요")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)

                        Text("왼쪽 사이드바에서 모니터링할 저장소를 클릭하면\n마지막 커밋 현황과 업데이트할 기능 메모를 관리할 수 있습니다.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 380)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }

    // MARK: - VS Code Style Bottom Status Bar
    private func bottomStatusBar(for repo: RepositoryItem) -> some View {
        let grp = terminalManager.group(for: repo.id)
        let isAnyRunning = grp?.isAnyTabRunning ?? false
        let tabCount = grp?.tabs.count ?? 0

        return HStack(spacing: 12) {
            // 터미널 토글 버튼
            Button(action: {
                terminalManager.togglePanel(for: repo.id, name: repo.name, localPath: viewModel.localDirectoryPath)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(terminalManager.isPanelVisible ? .accentColor : .secondary)

                    Text("터미널")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(terminalManager.isPanelVisible ? .primary : .secondary)

                    Circle()
                        .fill(isAnyRunning ? AppTheme.activeGreen : Color.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)

                    if tabCount > 1 {
                        Text("\(tabCount)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(terminalManager.isPanelVisible ? Color.accentColor.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("`", modifiers: .control)
            .help("터미널 패널 열기/닫기 (⌃~)")

            // 브랜치 정보
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                Text(repo.defaultBranch)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.secondary)

            // 기본 AI 에이전트 프리셋 뱃지
            HStack(spacing: 4) {
                Image(systemName: viewModel.defaultAIPreset.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(viewModel.defaultAIPreset.brandColor)
                Text(viewModel.defaultAIPreset.shortName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.04))
            .clipShape(Capsule())

            Spacer()

            // 메모 건수 및 방치일 요약
            HStack(spacing: 10) {
                Text("메모 \(viewModel.memos.count)건")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(staleColor(viewModel.staleStatus))
                        .frame(width: 6, height: 6)
                    Text(viewModel.staleStatus.displayBadge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(staleColor(viewModel.staleStatus))
                }

                // 파일 탐색기 사이드바 토글
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isFileTreeVisible.toggle()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "sidebar.right")
                        Text("파일 탐색기")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isFileTreeVisible ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("로컬 디렉토리 파일 탐색기 토글")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4.5)
        .background(Color(nsColor: NSColor.windowBackgroundColor).opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.primary.opacity(0.06)),
            alignment: .top
        )
    }

    // MARK: - Compact & Refined Repository Header Bar
    private func repositoryHeaderBar(for repo: RepositoryItem) -> some View {
        VStack(spacing: 7) {
            // 상단 주요 행: 이름, 상태 뱃지, 언어, 퀵 액션
            HStack(spacing: 8) {
                // 저장소 아이콘
                Image(systemName: repo.isPrivate ? "lock.shield.fill" : "folder.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.accentColor)

                // 저장소 전체 이름
                Text(repo.fullName)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .lineLimit(1)

                // Private / Fork 뱃지
                if repo.isPrivate {
                    HStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                        Text("Private")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                }

                if repo.isFork {
                    HStack(spacing: 2) {
                        Image(systemName: "tuningfork")
                        Text("Fork")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.14))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                }

                // D-Day 방치 상태 뱃지 (미니멀 캡슐)
                let status = viewModel.staleStatus
                HStack(spacing: 4) {
                    Circle()
                        .fill(staleColor(status))
                        .frame(width: 5, height: 5)
                    Text(status.displayBadge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                    Text(status.description)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(staleColor(status).opacity(0.12))
                .foregroundColor(staleColor(status))
                .clipShape(Capsule())

                // 주 언어 칩
                if let lang = repo.language, !lang.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.languageColor(for: lang))
                            .frame(width: 6, height: 6)
                        Text(lang)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
                }

                Spacer()

                // 퀵 액션 (파일 탐색기 토글, 터미널 패널, GitHub 열기)
                HStack(spacing: 6) {
                    // 파일 탐색기 사이드바 토글
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isFileTreeVisible.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sidebar.right")
                                .foregroundColor(isFileTreeVisible ? .accentColor : .secondary)
                            Text("파일 탐색기")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("오른쪽 로컬 디렉토리 파일 탐색기 열기/닫기")

                    // 터미널 토글 버튼
                    Button(action: {
                        terminalManager.togglePanel(for: repo.id, name: repo.name, localPath: viewModel.localDirectoryPath)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal.fill")
                                .foregroundColor(terminalManager.isPanelVisible ? .accentColor : .secondary)
                            Text("터미널")
                                .font(.system(size: 11, weight: .medium))

                            if let grp = terminalManager.group(for: repo.id) {
                                if grp.isAnyTabRunning {
                                    Circle()
                                        .fill(AppTheme.activeGreen)
                                        .frame(width: 5, height: 5)
                                }
                                if grp.tabs.count > 1 {
                                    Text("\(grp.tabs.count)")
                                        .font(.system(size: 8, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 3)
                                        .padding(.vertical, 1)
                                        .background(Color.accentColor.opacity(0.18))
                                        .foregroundColor(.accentColor)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("하단 터미널 패널 열기/닫기 (⌃~)")

                    // GitHub 웹페이지 열기
                    Link(destination: repo.htmlUrl) {
                        HStack(spacing: 3) {
                            Text("GitHub")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // 하단 보조 행: 설명, 최신 커밋, 저장소 메트릭 (스타, 포크, 이슈, 브랜치)
            HStack(spacing: 12) {
                if let desc = repo.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let date = repo.latestActivityDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(AppTheme.relativeTimeString(from: date))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        if let message = repo.lastCommitMessage {
                            Text("· \"\(message.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                } else if viewModel.isLoadingCommit {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.5)
                        Text("커밋 내역 로딩 중...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 스타, 포크, 이슈, 브랜치 메트릭
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                        Text("\(repo.stargazersCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "tuningfork")
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                        Text("\(repo.forksCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    if repo.openIssuesCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.warningAmber)
                            Text("\(repo.openIssuesCount)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                            .foregroundColor(.purple)
                        Text(repo.defaultBranch)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.primary.opacity(0.06)),
            alignment: .bottom
        )
    }

    private func staleColor(_ status: StaleStatus) -> Color {
        switch status {
        case .active: return AppTheme.activeGreen
        case .warning: return AppTheme.warningAmber
        case .stale: return AppTheme.staleRose
        case .unknown: return Color.gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
