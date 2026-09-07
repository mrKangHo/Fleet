import SwiftUI

/// 로컬 CLI 도구 및 환경 탐색기 뷰 (Stitch: CLI & Envs)
public struct CliEnvironmentsView: View {
    let localPath: String?
    let settings: AppSettings
    let onOpenSettings: () -> Void
    let onChooseFolder: () -> Void
    let onOpenInFinder: () -> Void
    let onOpenTerminal: () -> Void

    @State private var isRescanning = false

    public init(
        localPath: String?,
        settings: AppSettings = .default,
        onOpenSettings: @escaping () -> Void,
        onChooseFolder: @escaping () -> Void,
        onOpenInFinder: @escaping () -> Void,
        onOpenTerminal: @escaping () -> Void
    ) {
        self.localPath = localPath
        self.settings = settings
        self.onOpenSettings = onOpenSettings
        self.onChooseFolder = onChooseFolder
        self.onOpenInFinder = onOpenInFinder
        self.onOpenTerminal = onOpenTerminal
    }

    private struct CliToolInfo: Identifiable {
        let id = UUID()
        let name: String
        let binaryName: String
        let isInstalled: Bool
        let path: String?
        let version: String?
        let iconName: String
        let latency: String
    }

    private var discoveredTools: [CliToolInfo] {
        let tools: [(String, String, String, String)] = [
            ("Google Antigravity CLI", "agy", "atom", "18ms"),
            ("Claude Code CLI", "claude", "brain.head.profile", "24ms"),
            ("Aider AI Pair Programmer", "aider", "hammer.fill", "35ms"),
            ("Cursor CLI Editor Bridge", "cursor", "cursorarrow.rays", "32ms"),
            ("Git Version Control", "git", "arrow.triangle.branch", "12ms"),
            ("Node.js Runtime", "node", "shippingbox.fill", "15ms")
        ]

        return tools.map { name, bin, icon, latency in
            let installed = AIAgentDiscovery.isInstalled(binaryName: bin)
            let path = AIAgentDiscovery.resolvedPath(binaryName: bin)
            let ver = AIAgentDiscovery.resolvedVersion(binaryName: bin)
            return CliToolInfo(
                name: name,
                binaryName: bin,
                isInstalled: installed,
                path: path,
                version: ver,
                iconName: icon,
                latency: latency
            )
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                            Text("CLI Runtimes & Local Environment")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                        }
                        Text("Mac 로컬 터미널 PATH와 연동된 AI 에이전트 및 개발 도구들의 런타임 현황입니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Button(action: {
                        isRescanning = true
                        AIAgentDiscovery.invalidateCache()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isRescanning = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isRescanning {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("도구 재스캔")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // MARK: - Local Path Environment Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        Text("로컬 작업 디렉토리 경로 (Working Directory)")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        if let path = localPath, !path.isEmpty {
                            Text(path)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(6)

                            Button("Finder 열기", action: onOpenInFinder)
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                            Button("터미널 열기", action: onOpenTerminal)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        } else {
                            Text("선택된 저장소의 로컬 디렉토리가 아직 연결되지 않았습니다.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("로컬 폴더 연결...", action: onChooseFolder)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 12)

                // MARK: - Discovered CLI Tools Table
                VStack(alignment: .leading, spacing: 12) {
                    Text("탐지된 CLI 도구 목록 (PATH Detection)")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)

                    VStack(spacing: 8) {
                        ForEach(discoveredTools) { tool in
                            HStack(spacing: 12) {
                                Image(systemName: tool.iconName)
                                    .font(.system(size: 16))
                                    .frame(width: 24)
                                    .foregroundColor(tool.isInstalled ? AppTheme.activeGreen : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(tool.name)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("(\(tool.binaryName))")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    if let path = tool.path {
                                        Text(path)
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if tool.isInstalled {
                                    if let ver = tool.version {
                                        Text(ver)
                                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(Capsule())
                                    }

                                    Text("설치됨 (Ready)")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
                                        .background(AppTheme.activeGreen.opacity(0.14))
                                        .foregroundColor(AppTheme.activeGreen)
                                        .clipShape(Capsule())

                                    Text(tool.latency)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("미설치")
                                        .font(.system(size: 10.5, weight: .medium))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
                                        .background(Color.secondary.opacity(0.1))
                                        .foregroundColor(.secondary)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(12)
                            .glassCard(cornerRadius: 8)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
