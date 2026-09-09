import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab
    @AppStorage("workmanager_app_language") private var appLanguageRaw: String = AppLanguage.system.rawValue
    var onSaved: (() -> Void)?

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "일반"
        case ai = "AI 에이전트 CLI"
        case voice = "음성 어시스턴트"
        case stalePolicy = "D-Day 방치 알림"
        case terminalGit = "터미널 & Git"
        case shortcuts = "단축키"
        case accounts = "계정 & 인증"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .general: return "gearshape"
            case .ai: return "cpu"
            case .voice: return "mic"
            case .stalePolicy: return "calendar.badge.clock"
            case .terminalGit: return "terminal"
            case .shortcuts: return "command"
            case .accounts: return "lock.shield"
            }
        }
    }

    public init(initialTab: SettingsTab = .ai, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: SettingsViewModel())
        self._selectedTab = State(initialValue: initialTab)
        self.onSaved = onSaved
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Stitch 모던 윈도우 헤더
            HStack(alignment: .center) {
                HStack(spacing: 9) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("환경설정 (Preferences)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("Fleet v1.4.2")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: {
                    viewModel.save()
                    onSaved?()
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("w", modifiers: .command)
                .help("닫기 (⌘W)")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            Divider()

            // MARK: - Stitch 세그먼트 탭 선택기 (6개 탭)
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.25)) { selectedTab = tab }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(LocalizedStringKey(tab.rawValue))
                                .font(.system(size: 11.5, weight: selectedTab == tab ? .bold : .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // MARK: - 탭별 콘텐츠 영역
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        generalTabContent
                    case .ai:
                        aiTabContent
                    case .voice:
                        voiceTabContent
                    case .stalePolicy:
                        stalePolicyTabContent
                    case .terminalGit:
                        terminalGitTabContent
                    case .shortcuts:
                        shortcutsTabContent
                    case .accounts:
                        accountsTabContent
                    }
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // MARK: - Stitch 모달 푸터
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("환경설정: ~/.workmanager/config.json (실시간 자동 동기화)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("기본값 복원 (Reset Defaults)") {
                    viewModel.resetDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("완료 (Done) ⌘W") {
                    viewModel.save()
                    onSaved?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .frame(width: 680, height: 580)
        .onAppear {
            if viewModel.settings.githubToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedTab = .accounts
            }
        }
    }

    // MARK: - 1. 일반 (General) 탭
    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("표시 언어 (Display Language)")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                Text("앱에 표시되는 언어를 선택합니다 (시스템 언어와 별도로 지정 가능)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("언어")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                Picker("언어", selection: $appLanguageRaw) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
            }
            .padding(14)
            .glassCard(cornerRadius: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text("일반 동작 및 동기화 설정")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                Text("저장소 필터링과 자동 새로고침 주기를 관리합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $viewModel.settings.excludeArchived) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("보관(Archived) 저장소 제외")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                        Text("더 이상 개발하지 않는 읽기 전용 보관 저장소를 목록에서 숨깁니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Toggle(isOn: $viewModel.settings.excludeForks) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("포크(Fork) 저장소 제외")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                        Text("외부 프로젝트를 포크한 저장소를 사이드바에서 제외합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("백그라운드 자동 새로고침 주기")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                        Text("GitHub API를 통해 최신 커밋 및 활동 기록을 주기적으로 동기화합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $viewModel.settings.autoRefreshIntervalMinutes) {
                        Text("15분").tag(15)
                        Text("30분").tag(30)
                        Text("60분 (기본값)").tag(60)
                        Text("수동").tag(0)
                    }
                    .frame(width: 140)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 12)
        }
    }

    // MARK: - 2. AI 에이전트 CLI 탭 (Stitch Artboard 1)
    private var aiTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // MARK: Hero Banner
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.activeGreen)
                            .frame(width: 8, height: 8)
                        Text("AI 에이전트 CLI 오케스트레이션")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                        Text("Native Engine Active")
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.activeGreen.opacity(0.16))
                            .foregroundColor(AppTheme.activeGreen)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text("Keychain Sandbox")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }

                Text("작업 백로그 메모 카드를 클릭하여 AI 코딩 에이전트에게 자동 완수 작업을 지시합니다. 로컬 CLI 환경을 직접 탐지하여 최고 속도로 브릿징합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(14)
            .glassCard(cornerRadius: 12)

            // MARK: Section 1: Default AI CLI Engine
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("기본 에이전트 엔진 (Default AI CLI Engine)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        viewModel.rescanCLI()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("설치된 CLI 재스캔")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // 3 Interactive Cards (Antigravity, Claude Code, Cursor/Aider)
                HStack(alignment: .top, spacing: 10) {
                    agentCard(
                        preset: .antigravity,
                        title: "Antigravity CLI",
                        icon: "atom",
                        color: Color(red: 0.42, green: 0.58, blue: 1.00),
                        defaultPath: "/opt/homebrew/bin/agy"
                    )
                    agentCard(
                        preset: .claude,
                        title: "Claude Code CLI",
                        icon: "brain.head.profile",
                        color: Color(red: 0.96, green: 0.54, blue: 0.32),
                        defaultPath: "/opt/homebrew/bin/claude"
                    )
                    agentCard(
                        preset: .aider,
                        title: "Cursor CLI & Aider",
                        icon: "cursorarrow.rays",
                        color: Color(red: 0.28, green: 0.68, blue: 0.98),
                        defaultPath: "/usr/local/bin/aider"
                    )
                }

                // 기타 설치된 AI 또는 커스텀 CLI 선택기
                HStack {
                    Text("기타 CLI 선택:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.settings.aiAgentPreset) {
                        ForEach(AppSettings.AIAgentPreset.allCases) { p in
                            Text(LocalizedStringKey(p.rawValue)).tag(p)
                        }
                    }
                    .frame(width: 200)

                    Spacer()
                }
                .padding(.top, 4)
            }

            // MARK: Section 2: Runtime & Permissions (Stitch)
            VStack(alignment: .leading, spacing: 12) {
                Text("에이전트 실행 환경 및 자동화 권한 (Runtime & Permissions)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $viewModel.settings.dangerouslySkipPermissions) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("권한 확인 자동 승인")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                Text("--dangerously-skip-permissions")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                            Text("터미널에서 AI 에이전트가 파일 수정이나 도구 실행 시 대화형 승인 대기 없이 즉시 작업을 자율 완수하도록 합니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    Toggle(isOn: $viewModel.settings.autoCommitOnTaskCompletion) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("자동 Git 커밋 및 체크리스트 동기화 (Auto Git Commit)")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                            Text("AI가 코드 변경 및 테스트 패스를 완료하면 메모 카드를 자동으로 '완료됨' 컬럼으로 이동하고 규격 커밋을 남깁니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    // Terminal Streaming Choice (Stitch radio options)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("터미널 스트리밍 출력 방식:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Button(action: { viewModel.settings.streamInEmbeddedTerminal = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.settings.streamInEmbeddedTerminal ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(viewModel.settings.streamInEmbeddedTerminal ? .accentColor : .secondary)
                                Text("하단 터미널 드로어에서 즉시 스트리밍 및 양방향 상호작용 (Fleet 통합 권장)")
                                    .font(.system(size: 11.5, weight: viewModel.settings.streamInEmbeddedTerminal ? .semibold : .regular))
                            }
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.settings.streamInEmbeddedTerminal = false }) {
                            HStack(spacing: 8) {
                                Image(systemName: !viewModel.settings.streamInEmbeddedTerminal ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(!viewModel.settings.streamInEmbeddedTerminal ? .accentColor : .secondary)
                                Text("독립 외부 터미널 세션으로 분기 (Ghostty, iTerm2, Kitty 전송)")
                                    .font(.system(size: 11.5, weight: !viewModel.settings.streamInEmbeddedTerminal ? .semibold : .regular))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .glassCard(cornerRadius: 12)
            }
        }
    }

    // MARK: - 음성 어시스턴트 탭
    private var voiceTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.accentColor)
                    Text("Jarvis 음성 어시스턴트")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                }
                Text("메인 화면 상단의 마이크 버튼(⌘⇧J)으로 음성 명령을 사용할 때 적용되는 목소리와 말하기 속도를 설정합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(14)
            .glassCard(cornerRadius: 12)

            VStack(alignment: .leading, spacing: 14) {
                Text("보이스 (Voice)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: Binding(
                        get: { viewModel.settings.voiceIdentifier ?? "" },
                        set: { viewModel.settings.voiceIdentifier = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("자동 선택 (Enhanced 우선)").tag("")
                        ForEach(viewModel.availableKoreanVoices) { voice in
                            Text(voice.isEnhanced ? "\(voice.name) (Enhanced)" : voice.name).tag(voice.id)
                        }
                    }
                    .frame(width: 280)

                    if viewModel.availableKoreanVoices.filter({ $0.isEnhanced }).isEmpty {
                        Text("Enhanced 보이스가 설치되어 있지 않습니다. 시스템 설정 → 손쉬운 사용 → 낭독 콘텐츠에서 한국어 Enhanced 보이스를 내려받으면 더 자연스러운 목소리를 쓸 수 있어요.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("말하기 속도")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(speedLabel(for: viewModel.settings.voiceSpeechRate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $viewModel.settings.voiceSpeechRate, in: 0.3...0.65)
                    }

                    Button(action: { viewModel.previewVoice() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill")
                            Text("미리 듣기")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(14)
                .glassCard(cornerRadius: 12)
            }
        }
    }

    private func speedLabel(for rate: Float) -> String {
        switch rate {
        case ..<0.4: return "느리게"
        case 0.4..<0.55: return "보통"
        default: return "빠르게"
        }
    }

    // MARK: - Agent Card Builder (Stitch Style)
    private func agentCard(
        preset: AppSettings.AIAgentPreset,
        title: String,
        icon: String,
        color: Color,
        defaultPath: String
    ) -> some View {
        let isSelected = viewModel.settings.aiAgentPreset == preset || (preset == .aider && viewModel.settings.aiAgentPreset == .cursor)
        let isInstalled = preset.isInstalled || (preset == .aider && AppSettings.AIAgentPreset.cursor.isInstalled)
        let resolvedPath = preset.detectedPath ?? defaultPath
        let ver = preset.detectedVersion

        return Button(action: {
            withAnimation(.spring(response: 0.25)) {
                viewModel.settings.aiAgentPreset = preset
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Card Header
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(color)

                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    if isSelected {
                        Text("기본값")
                            .font(.system(size: 8.5, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }

                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(isInstalled ? AppTheme.activeGreen : Color.secondary.opacity(0.5))
                        .frame(width: 5, height: 5)
                    Text(isInstalled ? (ver ?? "설치됨 (Ready)") : "미설치")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(isInstalled ? AppTheme.activeGreen : .secondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background((isInstalled ? AppTheme.activeGreen : Color.secondary).opacity(0.12))
                .clipShape(Capsule())

                // Path Chip
                Text(resolvedPath)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(4)

                Divider()

                // Capabilities
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(preset.capabilities.prefix(3), id: \.self) { cap in
                        HStack(alignment: .top, spacing: 4) {
                            Text("✓")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(color)
                            Text(cap)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(2)
                        }
                    }
                }

                Spacer(minLength: 6)

                // Card Footer (Shortcut & Latency)
                HStack {
                    Text(preset.shortcutHint)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(preset.latencyHint)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.activeGreen)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
            .background(isSelected ? color.opacity(0.08) : Color.clear)
            .glassCard(cornerRadius: 10, isHovered: isSelected)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? color : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.6 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. D-Day 방치 알림 탭 (Stitch Artboard 2)
    private var stalePolicyTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Hero Banner
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.warningAmber)
                        Text("D-Day 방치 감지 및 스마트 알림 설정 (Stale Alerts Policy)")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                    }
                    Spacer()
                    Text("원격 캘린더/데몬 연동 (Daemon v2.1)")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }

                Text("마지막 Git 커밋 시점을 기준으로 저장소의 활동성을 측정하고, 장기 방치된 사이드 프로젝트가 유실되지 않도록 단계별 알림을 제공합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(14)
            .glassCard(cornerRadius: 12)

            // MARK: 3-Stage Visual Policy Cards (Stitch)
            VStack(alignment: .leading, spacing: 10) {
                Text("방치 판정 기준 설정 (Global Stale Thresholds)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(alignment: .top, spacing: 10) {
                    // Stage 1: Watch (주의)
                    stageCard(
                        stage: "Stage 1",
                        title: "주의 (Watch)",
                        days: "\(viewModel.settings.warningThresholdDays)일 무활동",
                        color: AppTheme.warningAmber,
                        icon: "clock.badge.exclamationmark.fill",
                        badge: nil,
                        points: [
                            "사이드바 노란색 점 및 뱃지 표시",
                            "주간 리포트 요약에 관심 목록으로 포함"
                        ]
                    )

                    // Stage 2: Stale (방치 경고)
                    stageCard(
                        stage: "Stage 2",
                        title: "방치 경고 (Stale)",
                        days: "\(viewModel.settings.staleThresholdDays)일 무활동",
                        color: AppTheme.staleRose,
                        icon: "exclamationmark.triangle.fill",
                        badge: "기본 권장 설정",
                        points: [
                            "macOS 독(Dock) 뱃지 카운트 증가",
                            "칸반 14일 경과 리마인더 카드 푸시"
                        ]
                    )

                    // Stage 3: Critical (방치 위험)
                    stageCard(
                        stage: "Stage 3",
                        title: "방치 위험 (Critical)",
                        days: "\(viewModel.settings.criticalThresholdDays)일 무활동",
                        color: Color(red: 0.85, green: 0.20, blue: 0.40),
                        icon: "exclamationmark.octagon.fill",
                        badge: "긴급 알림",
                        points: [
                            "macOS 시스템 알림 센터 긴급 푸시",
                            "AI 복구 마이크로 태스크 카드 자동 생성"
                        ]
                    )
                }

                // Interactive Stepper Control (Stitch: [ - 14일 + ])
                HStack(spacing: 12) {
                    Text("사용자 지정 방치 기준일 (Stale Threshold):")
                        .font(.system(size: 11.5, weight: .semibold))

                    Spacer()

                    HStack(spacing: 4) {
                        Button(action: {
                            if viewModel.settings.staleThresholdDays > 7 {
                                viewModel.settings.staleThresholdDays -= 1
                            }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        Text("\(viewModel.settings.staleThresholdDays)일")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(width: 44, alignment: .center)

                        Button(action: {
                            if viewModel.settings.staleThresholdDays < 180 {
                                viewModel.settings.staleThresholdDays += 1
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(3)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                }
                .padding(12)
                .glassCard(cornerRadius: 8)
            }

            // MARK: Notification Channels
            VStack(alignment: .leading, spacing: 12) {
                Text("알림 채널 및 발송 옵션 (macOS Notification Channels)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle(isOn: $viewModel.settings.isNotificationEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("macOS 시스템 알림 센터 배너 & 사운드 (Basso Alert)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                Text("기준일을 초과하여 장기 방치된 저장소를 macOS 알림 센터로 안내합니다.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        Spacer()

                        Button("권한 요청") {
                            Task { await viewModel.requestNotificationPermission() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Divider()

                    Toggle(isOn: $viewModel.settings.isDockBadgeEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("macOS 독(Dock) 미확인 방치 카운트 뱃지 노출")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                            Text("방치 상태인 저장소 개수를 Mac Dock 아이콘 위에 숫자로 실시간 표시합니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    Toggle(isOn: $viewModel.settings.weeklyReportEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("주간 방치 리포트 요약 알림 (매주 월요일 09:00)")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                            Text("한 주간 활동이 없었던 사이드 프로젝트와 권장 재개 메모를 요약해 안내합니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(14)
                .glassCard(cornerRadius: 12)
            }
        }
    }

    private func stageCard(
        stage: String,
        title: String,
        days: String,
        color: Color,
        icon: String,
        badge: String?,
        points: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stage)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                Spacer()
                if let b = badge {
                    Text(b)
                        .font(.system(size: 8.5, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(color.opacity(0.18))
                        .foregroundColor(color)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }

            Text(days)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Divider()

            VStack(alignment: .leading, spacing: 3) {
                ForEach(points, id: \.self) { pt in
                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                            .foregroundColor(color)
                        Text(pt)
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(color.opacity(0.05))
        .glassCard(cornerRadius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - 4. 터미널 & Git 탭
    private var terminalGitTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("터미널 환경 및 로컬 Git 경로")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                Text("내장 터미널 렌더링 스타일 및 로컬 저장소 탐색 기본 디렉토리를 지정합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("터미널 프로파일 테마 선택:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.settings.terminalApp) {
                        ForEach(AppSettings.TerminalApp.allCases) { app in
                            Text(LocalizedStringKey(app.rawValue)).tag(app)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("기본 로컬 저장소 탐색 경로:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("예: ~/Documents 또는 ~/Projects", text: $viewModel.settings.defaultProjectsDirectory)
                            .textFieldStyle(.roundedBorder)

                        Button("찾아보기...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                viewModel.settings.defaultProjectsDirectory = url.path
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Text("저장소 이름과 일치하는 폴더를 이 위치에서 자동으로 감지하여 터미널을 실행합니다.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("실제 터미널 실행 명령어 미리보기:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(viewModel.settings.aiAgentPreset.commandTemplate(dangerouslySkipPermissions: viewModel.settings.dangerouslySkipPermissions))
                        .font(.system(size: 11.5, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 12)
        }
    }

    // MARK: - 5. 단축키 (Shortcuts) 탭
    private var shortcutsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("키보드 단축키 안내 (Keyboard Shortcuts)")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                Text("마우스 없이 빠른 저장소 탐색과 AI 작업 수행을 지원합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                shortcutRow(keys: ["⌘", "K"], description: "빠른 저장소 및 기능 검색")
                shortcutRow(keys: ["⌘", "R"], description: "GitHub 저장소 및 최신 커밋 즉시 새로고침")
                shortcutRow(keys: ["⌃", "`"], description: "하단 터미널 패널 열기 / 닫기")
                shortcutRow(keys: ["⌥", "B"], description: "오른쪽 로컬 디렉토리 파일 탐색기 토글")
                shortcutRow(keys: ["⌘", ","], description: "환경설정 창 열기")
                shortcutRow(keys: ["⌘", "1~4"], description: "상단 Kanban / Health / Workflows / CLI 탭 전환")
                shortcutRow(keys: ["⌘", "W"], description: "열려있는 모달 창 닫기")
            }
            .padding(14)
            .glassCard(cornerRadius: 12)
        }
    }

    private func shortcutRow(keys: [String], description: String) -> some View {
        HStack {
            Text(description)
                .font(.system(size: 12))
            Spacer()
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                        )
                }
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - 6. 계정 & 인증 (Accounts & Auth) 탭
    private var accountsTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitHub Personal Access Token (PAT)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                    Text("저장소 메타데이터와 커밋 기록 조회를 위한 인증 토큰을 관리합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    SecureField("ghp_... 또는 github_pat_...", text: $viewModel.settings.githubToken)
                        .textFieldStyle(.roundedBorder)

                    Button(action: {
                        Task { await viewModel.testToken() }
                    }) {
                        if viewModel.isTestingToken {
                            ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                        } else {
                            Text("연동 테스트")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isTestingToken || viewModel.settings.githubToken.isEmpty)
                }

                if let result = viewModel.tokenTestResult {
                    HStack(spacing: 6) {
                        Image(systemName: (viewModel.isTokenValid == true) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor((viewModel.isTokenValid == true && viewModel.hasRepoPermission != false) ? AppTheme.activeGreen : AppTheme.warningAmber)
                        Text(result)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor((viewModel.isTokenValid == true && viewModel.hasRepoPermission != false) ? AppTheme.activeGreen : AppTheme.warningAmber)
                        Spacer()
                    }
                    .padding(8)
                    .background(((viewModel.isTokenValid == true && viewModel.hasRepoPermission != false) ? AppTheme.activeGreen : AppTheme.warningAmber).opacity(0.12))
                    .cornerRadius(6)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 12)

            // 비공개 저장소 안내 가이드 카드
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                    Text("비공개(Private) 저장소를 불러오려면?")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                }

                Text("Classic 토큰 발급 시 [repo] 체크박스(Full control of private repositories)에 체크해야 비공개 저장소를 안전하게 동기화할 수 있습니다.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Link(destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=Fleet%20macOS")!) {
                    HStack(spacing: 4) {
                        Text("GitHub에서 repo 권한 토큰 발급하기 ↗")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 12)
        }
    }
}
