import SwiftUI
import AppKit

public struct RepositoryDetailView: View {
    @ObservedObject var viewModel: RepositoryDetailViewModel
    var onMemoCountChanged: ((Int) -> Void)?

    @ObservedObject private var terminalManager = TerminalSessionManager.shared
    @State private var showCopiedFeedback = false

    public init(viewModel: RepositoryDetailViewModel, onMemoCountChanged: ((Int) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onMemoCountChanged = onMemoCountChanged
    }

    public var body: some View {
        Group {
            if let repo = viewModel.repository {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            // MARK: - 1. Hero Header (저장소 기본 정보 및 액션 버튼)
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top, spacing: 14) {
                                    // 소유자 아바타 또는 저장소 아이콘
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.12))
                                            .frame(width: 48, height: 48)

                                        Image(systemName: repo.isPrivate ? "lock.shield.fill" : "folder.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.accentColor)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(repo.fullName)
                                                .font(.system(.title2, design: .rounded))
                                                .fontWeight(.bold)

                                            if repo.isPrivate {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "lock.fill")
                                                    Text("Private")
                                                }
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2.5)
                                                .background(Color.secondary.opacity(0.15))
                                                .clipShape(Capsule())
                                            }

                                            if repo.isFork {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "tuningfork")
                                                    Text("Fork")
                                                }
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2.5)
                                                .background(Color.blue.opacity(0.14))
                                                .foregroundColor(.blue)
                                                .clipShape(Capsule())
                                            }
                                        }

                                        if let desc = repo.description, !desc.isEmpty {
                                            Text(desc)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    // Quick Actions (GitHub 열기, Clone URL 복사)
                                    HStack(spacing: 8) {
                                        Button(action: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString("https://github.com/\(repo.fullName).git", forType: .string)
                                            withAnimation { showCopiedFeedback = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                withAnimation { showCopiedFeedback = false }
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                                                    .foregroundColor(showCopiedFeedback ? AppTheme.activeGreen : .secondary)
                                                Text(showCopiedFeedback ? "복사됨!" : "Clone URL")
                                                    .font(.system(size: 11, weight: .medium))
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                        Button(action: {
                                            terminalManager.togglePanel(for: repo.id, name: repo.name, localPath: viewModel.localDirectoryPath)
                                        }) {
                                            HStack(spacing: 5) {
                                                Image(systemName: "terminal.fill")
                                                    .foregroundColor(terminalManager.isPanelVisible ? .accentColor : .secondary)
                                                Text("터미널")
                                                    .font(.system(size: 11, weight: .medium))

                                                if let grp = terminalManager.group(for: repo.id) {
                                                    if grp.isAnyTabRunning {
                                                        Circle()
                                                            .fill(AppTheme.activeGreen)
                                                            .frame(width: 6, height: 6)
                                                            .shadow(color: AppTheme.activeGreen.opacity(0.8), radius: 2)
                                                    }
                                                    if grp.tabs.count > 1 {
                                                        Text("\(grp.tabs.count)")
                                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                                            .padding(.horizontal, 4)
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

                                        Link(destination: repo.htmlUrl) {
                                            HStack(spacing: 4) {
                                                Text("GitHub 열기")
                                                    .font(.system(size: 11, weight: .semibold))
                                                Image(systemName: "arrow.up.right")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    }
                                }

                                // 4구 메트릭 그리드 (Glass 카드)
                                HStack(spacing: 12) {
                                    metricTile(
                                        title: "주 언어",
                                        value: repo.language ?? "None",
                                        icon: "chevron.left.forwardslash.chevron.right",
                                        color: AppTheme.languageColor(for: repo.language)
                                    )
                                    metricTile(
                                        title: "스타",
                                        value: "\(repo.stargazersCount)",
                                        icon: "star.fill",
                                        color: .yellow
                                    )
                                    metricTile(
                                        title: "포크",
                                        value: "\(repo.forksCount)",
                                        icon: "tuningfork",
                                        color: .blue
                                    )
                                    metricTile(
                                        title: "오픈 이슈",
                                        value: "\(repo.openIssuesCount)",
                                        icon: "exclamationmark.circle.fill",
                                        color: repo.openIssuesCount > 0 ? AppTheme.warningAmber : .secondary
                                    )
                                    metricTile(
                                        title: "브랜치",
                                        value: repo.defaultBranch,
                                        icon: "arrow.triangle.branch",
                                        color: .purple
                                    )
                                }

                                Divider()

                                // MARK: - 로컬 작업 폴더 연결 바 (AI Agent 작업 위치)
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.localDirectoryPath != nil ? "folder.fill" : "folder.badge.questionmark")
                                        .foregroundColor(viewModel.localDirectoryPath != nil ? .accentColor : AppTheme.warningAmber)
                                        .font(.system(size: 13))

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("로컬 작업 디렉토리")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.secondary)

                                        if let path = viewModel.localDirectoryPath {
                                            Text(path)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        } else {
                                            Text("로컬 폴더가 연결되지 않았습니다 (AI 작업 시 필요)")
                                                .font(.system(size: 11))
                                                .foregroundColor(AppTheme.warningAmber)
                                        }
                                    }

                                    Spacer()

                                    if let path = viewModel.localDirectoryPath {
                                        Button(action: {
                                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                        }) {
                                            Image(systemName: "arrow.up.forward.app")
                                                .font(.system(size: 11))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Finder에서 보기")
                                    }

                                    Button(viewModel.localDirectoryPath == nil ? "폴더 연결" : "폴더 변경") {
                                        viewModel.chooseLocalFolder()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(10)
                                .background(Color.primary.opacity(0.025))
                                .cornerRadius(8)
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 14)

                            // 피드백 배너 (성공 / 실패)
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
                                .padding(10)
                                .background(AppTheme.activeGreen.opacity(0.12))
                                .cornerRadius(8)
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
                                .padding(10)
                                .background(AppTheme.staleRose.opacity(0.12))
                                .cornerRadius(8)
                            }

                            // MARK: - 2. 방치 상태 & 마지막 커밋 인포 배너
                            let status = viewModel.staleStatus
                            HStack(spacing: 18) {
                                // D-Day 그래픽 뱃지
                                VStack(spacing: 3) {
                                    Text(status.displayBadge)
                                        .font(.system(size: 26, weight: .black, design: .rounded))
                                        .foregroundColor(staleColor(status))

                                    Text(status.description)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(staleColor(status))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 145)
                                .padding(.vertical, 14)
                                .background(staleColor(status).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(staleColor(status).opacity(0.25), lineWidth: 1)
                                )

                                // 마지막 커밋 정보
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 12))
                                        .foregroundColor(.secondary)

                                        if let date = repo.latestActivityDate {
                                            Text("마지막 활동: \(formatDate(date)) (\(AppTheme.relativeTimeString(from: date)))")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("마지막 활동 기록 없음")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    if let message = repo.lastCommitMessage {
                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: "quote.opening")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)

                                            Text(message.trimmingCharacters(in: .whitespacesAndNewlines))
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                        .padding(8)
                                        .background(Color.primary.opacity(0.03))
                                        .cornerRadius(6)
                                    } else if viewModel.isLoadingCommit {
                                        HStack(spacing: 6) {
                                            ProgressView().scaleEffect(0.5)
                                            Text("최신 커밋 내역 로딩 중...")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Spacer()
                            }
                            .padding(14)
                            .glassCard(cornerRadius: 14)

                            // MARK: - 3. 업데이트 기능 메모 백로그
                            MemoTimelineView(
                                viewModel: viewModel,
                                onMemoCountChanged: onMemoCountChanged
                            )
                        }
                        .padding(22)
                    }
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

    // MARK: - Metric Tile Component
    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
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
