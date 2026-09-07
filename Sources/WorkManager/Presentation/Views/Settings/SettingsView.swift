import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab = .github
    var onSaved: (() -> Void)?

    enum SettingsTab: String, CaseIterable, Identifiable {
        case github = "GitHub 계정"
        case ai = "AI Agent CLI"
        case threshold = "방치 임계치"
        case notifications = "알림 & 독 뱃지"
        case filters = "동기화 필터"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .github: return "key.fill"
            case .ai: return "sparkles"
            case .threshold: return "calendar.badge.clock"
            case .notifications: return "bell.badge.fill"
            case .filters: return "line.3.horizontal.decrease.circle"
            }
        }
    }

    public init(onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: SettingsViewModel())
        self.onSaved = onSaved
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 모던 윈도우 헤더
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                    Text("환경설정")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                }

                Spacer()

                Button("저장 및 닫기") {
                    viewModel.save()
                    onSaved?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

            // MARK: - 세그먼트 탭 선택기
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.25)) { selectedTab = tab }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
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
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))

            Divider()

            // MARK: - 탭별 콘텐츠 영역
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .github:
                        githubTabContent
                    case .ai:
                        aiTabContent
                    case .threshold:
                        thresholdTabContent
                    case .notifications:
                        notificationsTabContent
                    case .filters:
                        filtersTabContent
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 580, height: 520)
    }

    // MARK: - AI Agent CLI 탭
    private var aiTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Agent CLI 연동 설정")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)

                Text("메모 카드에서 [작업수행 (AI)] 버튼을 클릭했을 때 기본으로 자동 실행할 AI 코딩 에이전트 및 실행 옵션을 구성합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: 1. 권한 스킵 옵션 카드
            VStack(alignment: .leading, spacing: 10) {
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

                        Text("터미널에서 Claude, Antigravity 등 AI 에이전트가 파일 수정이나 도구 실행 시 대화형 승인 대기 없이 즉시 작업을 자율 완수하도록 합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(14)
            .glassCard(cornerRadius: 10)

            // MARK: 2. CLI 도구 프리셋 선택
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("기본 AI 에이전트 도구 선택")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("작업 수행 시 언제든 다른 AI로 변경 가능")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Picker("기본 AI", selection: $viewModel.settings.aiAgentPreset) {
                    ForEach(AppSettings.AIAgentPreset.allCases) { preset in
                        HStack {
                            Image(systemName: preset.iconName)
                            Text(preset.rawValue)
                        }
                        .tag(preset)
                    }
                }
                .pickerStyle(.radioGroup)

                Divider()

                // 커맨드 라인 템플릿 실시간 프리뷰
                VStack(alignment: .leading, spacing: 4) {
                    Text("실제 터미널 실행 명령어 미리보기")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    if viewModel.settings.aiAgentPreset == .custom {
                        TextField("예: my-agent --dangerously-skip-permissions \"{prompt}\"", text: $viewModel.settings.customCliTemplate)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(viewModel.settings.aiAgentPreset.commandTemplate(dangerouslySkipPermissions: viewModel.settings.dangerouslySkipPermissions))
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(6)
                    }

                    Text("변수: `{prompt}` (자동 조립된 작업 요청 프롬프트로 치환됩니다)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Divider()

                // 기본 로컬 프로젝트 폴더
                VStack(alignment: .leading, spacing: 4) {
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
                    Text("저장소 이름과 일치하는 폴더를 이 위치에서 자동으로 감지합니다.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 10)
        }
    }

    // MARK: - 1. GitHub 계정 탭
    private var githubTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // MARK: 토큰 입력 카드
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitHub Personal Access Token (PAT)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)

                    Text("GitHub 저장소 및 커밋 기록을 동기화하기 위한 인증 토큰을 입력합니다.")
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

            // MARK: 비공개(Private) 저장소 로드 필수 가이드 카드
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("비공개(Private) 저장소를 불러오려면?")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                }

                Text("GitHub API는 토큰에 비공개 저장소 권한이 없더라도 오류를 띄우지 않고 공개(Public) 저장소만 내려줍니다. 비공개 저장소까지 모두 불러오려면 아래 권한 설정이 필요합니다:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)

                Divider()

                // Classic 토큰 안내
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("1. Classic 토큰 (ghp_... 권장)")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Link(destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=WorkManager%20macOS")!) {
                            HStack(spacing: 3) {
                                Text("repo 권한 토큰 발급 ↗")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                    }

                    Text("• 토큰 생성 시 최상단 [repo] 체크박스(Full control of private repositories)에 반드시 체크해야 합니다.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Divider()

                // Fine-grained 토큰 안내
                VStack(alignment: .leading, spacing: 4) {
                    Text("2. Fine-grained 토큰 (github_pat_...)")
                        .font(.system(size: 12, weight: .semibold))

                    Text("• Repository access: [All repositories] 선택")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("• Repository permissions: [Contents: Read-only], [Metadata: Read-only] 허용")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Divider()

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("토큰을 새로 발급하여 입력한 후 [저장 및 닫기]를 누르고 사이드바 하단 새로고침(Cmd+R)을 누르면 비공개 저장소가 즉시 동기화됩니다.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 12)
        }
    }

    // MARK: - 2. 방치 임계치 탭
    private var thresholdTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 방치(Stale) 기준
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(AppTheme.staleRose).frame(width: 8, height: 8)
                        Text("방치 판정 기준일")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    Text("\(viewModel.settings.staleThresholdDays)일")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.staleRose)
                }

                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.staleThresholdDays) },
                        set: { viewModel.settings.staleThresholdDays = Int($0) }
                    ),
                    in: 7...180,
                    step: 1
                )

                Text("마지막 커밋 후 이 기간이 경과하면 독 뱃지 카운트 및 시스템 알림 대상이 됩니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .glassCard(cornerRadius: 10)

            // 주의(Warning) 기준
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(AppTheme.warningAmber).frame(width: 8, height: 8)
                        Text("주의 판정 기준일")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    Text("\(viewModel.settings.warningThresholdDays)일")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.warningAmber)
                }

                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.warningThresholdDays) },
                        set: { viewModel.settings.warningThresholdDays = Int($0) }
                    ),
                    in: 3...60,
                    step: 1
                )

                Text("노란색 주의 상태로 표시하여 업데이트 시점이 다가왔음을 미리 안내합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .glassCard(cornerRadius: 10)
        }
    }

    // MARK: - 3. 알림 & 독 뱃지 탭
    private var notificationsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $viewModel.settings.isDockBadgeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("macOS 독(Dock) 뱃지 숫자 표시")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                        Text("방치된 저장소의 총 개수를 Dock 아이콘 우측 상단 뱃지로 실시간 노출합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                HStack(alignment: .center) {
                    Toggle(isOn: $viewModel.settings.isNotificationEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("방치 저장소 시스템 배너 알림")
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
            }
            .padding(14)
            .glassCard(cornerRadius: 10)
        }
    }

    // MARK: - 4. 동기화 필터 탭
    private var filtersTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                        Text("다른 사람의 저장소를 포크한 프로젝트를 목록에서 제외합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(14)
            .glassCard(cornerRadius: 10)
        }
    }
}
