import SwiftUI

/// AI 에이전트 오케스트레이션 및 작업 흐름 뷰 (Stitch: Agent Workflows)
public struct AgentWorkflowsView: View {
    let selectedRepo: RepositoryItem?
    let memos: [MemoItem]
    let settings: AppSettings
    let onOpenSettings: () -> Void
    let onExecuteTask: (MemoItem) -> Void
    let onOpenTerminal: () -> Void

    public init(
        selectedRepo: RepositoryItem?,
        memos: [MemoItem],
        settings: AppSettings = .default,
        onOpenSettings: @escaping () -> Void,
        onExecuteTask: @escaping (MemoItem) -> Void,
        onOpenTerminal: @escaping () -> Void
    ) {
        self.selectedRepo = selectedRepo
        self.memos = memos
        self.settings = settings
        self.onOpenSettings = onOpenSettings
        self.onExecuteTask = onExecuteTask
        self.onOpenTerminal = onOpenTerminal
    }

    private var activeMemos: [MemoItem] {
        memos.filter { $0.status == .inProgress }
    }

    private var pendingMemos: [MemoItem] {
        memos.filter { $0.status == .pending }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 20))
                                .foregroundColor(settings.aiAgentPreset.brandColor)
                            Text("Agent Workflows & Autonomous Tasks")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                        }
                        Text("연결된 AI CLI 에이전트와 백로그 작업 간의 실시간 오케스트레이션 상태입니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: onOpenSettings) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                            Text("에이전트 환경설정")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // MARK: - Active Engine Hero Card (Stitch: Native Engine Active)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(AppTheme.activeGreen)
                                .frame(width: 8, height: 8)
                            Text("AI 에이전트 CLI 오케스트레이션")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                            Text("Native Engine Active")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.activeGreen.opacity(0.16))
                                .foregroundColor(AppTheme.activeGreen)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text("Keychain Sandbox")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("현재 기본 엔진:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                Image(systemName: settings.aiAgentPreset.iconName)
                                    .foregroundColor(settings.aiAgentPreset.brandColor)
                                Text(settings.aiAgentPreset.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }

                        Divider().frame(height: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("바이너리 경로:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(settings.aiAgentPreset.detectedPath ?? "미감지")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Divider().frame(height: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("실행 지연시간:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(settings.aiAgentPreset.latencyHint)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.activeGreen)
                        }

                        Spacer()

                        Button(action: onOpenTerminal) {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal.fill")
                                Text("터미널 드로어 열기")
                            }
                            .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 12)

                // MARK: - Active & Pending Tasks Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("작업 큐 (Task Queue)")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(activeMemos.count + pendingMemos.count)개 작업")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    if activeMemos.isEmpty && pendingMemos.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.accentColor.opacity(0.7))
                            Text("대기 중인 AI 작업이 없습니다.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .glassCard(cornerRadius: 10)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(activeMemos) { memo in
                                taskRow(memo, isActive: true)
                            }
                            ForEach(pendingMemos) { memo in
                                taskRow(memo, isActive: false)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func taskRow(_ memo: MemoItem, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? AppTheme.activeGreen : AppTheme.warningAmber)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(memo.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(memo.priority.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                }
                if !memo.content.isEmpty {
                    Text(memo.content)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isActive {
                HStack(spacing: 5) {
                    ProgressView().scaleEffect(0.6)
                    Text("AI 자율 작업 수행 중...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.activeGreen)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.activeGreen.opacity(0.12))
                .clipShape(Capsule())
            } else {
                Button(action: { onExecuteTask(memo) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AI 실행")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 8)
    }
}
