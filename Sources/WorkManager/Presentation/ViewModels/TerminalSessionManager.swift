import Foundation
import SwiftUI
import AppKit
import SwiftTerm

/// 단일 터미널 탭 아이템 모델 (독립된 PTY 세션)
public final class TerminalTabItem: ObservableObject, Identifiable, LocalProcessTerminalViewDelegate {
    public let id: UUID
    public let repositoryId: Int
    public let repositoryName: String
    public var workingDirectory: String
    public let terminalView: LocalProcessTerminalView
    public let createdAt: Date

    @Published public var title: String
    @Published public var preset: AppSettings.AIAgentPreset?
    @Published public var isRunning: Bool = false
    @Published public var exitCode: Int32? = nil
    @Published public var hasExecutedTask: Bool = false

    public init(
        id: UUID = UUID(),
        repositoryId: Int,
        repositoryName: String,
        workingDirectory: String,
        preset: AppSettings.AIAgentPreset? = nil,
        customTitle: String? = nil
    ) {
        self.id = id
        self.repositoryId = repositoryId
        self.repositoryName = repositoryName
        self.workingDirectory = workingDirectory
        self.preset = preset
        self.createdAt = Date()

        if let custom = customTitle, !custom.isEmpty {
            self.title = custom
        } else if let p = preset {
            self.title = p.shortName
        } else {
            self.title = "터미널"
        }

        let options = TerminalOptions.default
        let view = LocalProcessTerminalView(frame: .zero, options: options)
        view.font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        view.nativeBackgroundColor = NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)
        view.nativeForegroundColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        view.caretColor = NSColor.systemTeal

        self.terminalView = view
        view.processDelegate = self

        startShell()
    }

    public func startShell() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let resolvedDir = workingDirectory.replacingOccurrences(of: "~", with: home)

        let targetDir: String
        if fileManager.fileExists(atPath: resolvedDir) {
            targetDir = resolvedDir
        } else {
            targetDir = home
        }

        // Homebrew 및 주요 CLI 경로 주입
        let pathEnv = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:\(home)/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = pathEnv + (env["PATH"].map { ":" + $0 } ?? "")
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = "ko_KR.UTF-8"
        env["LC_ALL"] = "ko_KR.UTF-8"
        env["WORKMANAGER_REPO"] = repositoryName

        let envArray = env.map { "\($0.key)=\($0.value)" }

        DispatchQueue.main.async {
            self.isRunning = true
            self.exitCode = nil
        }

        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["--login"],
            environment: envArray,
            currentDirectory: targetDir
        )
    }

    public func updateWorkingDirectoryIfNeeded(_ newPath: String) {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let resolved = newPath.replacingOccurrences(of: "~", with: home)
        guard resolved != workingDirectory, fileManager.fileExists(atPath: resolved) else { return }
        self.workingDirectory = resolved
        sendCommand("cd '\(resolved.replacingOccurrences(of: "'", with: "'\\''"))'")
    }

    public func sendCommand(_ command: String) {
        guard isRunning else {
            startShell()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.sendCommand(command)
            }
            return
        }

        let cmdToSend = command.hasSuffix("\n") ? command : command + "\n"
        let slice = ArraySlice(cmdToSend.utf8)
        terminalView.process.send(data: slice)
    }

    public func sendInterrupt() {
        guard isRunning else { return }
        terminalView.process.send(data: ArraySlice([0x03])) // Ctrl+C
    }

    public func clear() {
        sendCommand("clear")
    }

    public func restart() {
        terminalView.terminate()
        startShell()
    }

    public func terminate() {
        terminalView.terminate()
        isRunning = false
    }

    // MARK: - LocalProcessTerminalViewDelegate
    public func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    public func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        DispatchQueue.main.async {
            if !title.isEmpty && self.preset == nil {
                self.title = title
            }
        }
    }

    public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        if let dir = directory {
            DispatchQueue.main.async {
                self.workingDirectory = dir
            }
        }
    }

    public func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async {
            self.isRunning = false
            self.exitCode = exitCode
        }
    }
}

/// 하위 호환성을 위한 Typealias
public typealias RepositoryTerminalSession = TerminalTabItem

/// 특정 저장소에 속한 다중 터미널 탭 그룹
public final class RepositoryTerminalGroup: ObservableObject, Identifiable {
    public let id: Int // repositoryId
    public let repositoryName: String
    public var workingDirectory: String

    @Published public var tabs: [TerminalTabItem] = []
    @Published public var activeTabId: UUID?

    public init(repositoryId: Int, repositoryName: String, workingDirectory: String) {
        self.id = repositoryId
        self.repositoryName = repositoryName
        self.workingDirectory = workingDirectory
    }

    public var activeTab: TerminalTabItem? {
        if let id = activeTabId, let tab = tabs.first(where: { $0.id == id }) {
            return tab
        }
        return tabs.first
    }

    public var isAnyTabRunning: Bool {
        tabs.contains { $0.isRunning }
    }

    @discardableResult
    public func createTab(preset: AppSettings.AIAgentPreset? = nil, customTitle: String? = nil, autoSelect: Bool = true) -> TerminalTabItem {
        let countForPreset = tabs.filter { $0.preset == preset }.count
        let finalTitle: String
        if let custom = customTitle {
            finalTitle = custom
        } else if let p = preset {
            finalTitle = countForPreset > 0 ? "\(p.shortName) \(countForPreset + 1)" : p.shortName
        } else {
            let zshCount = tabs.filter { $0.preset == nil }.count
            finalTitle = zshCount > 0 ? "터미널 \(zshCount + 1)" : "터미널"
        }

        let newTab = TerminalTabItem(
            repositoryId: id,
            repositoryName: repositoryName,
            workingDirectory: workingDirectory,
            preset: preset,
            customTitle: finalTitle
        )

        tabs.append(newTab)
        if autoSelect || activeTabId == nil {
            activeTabId = newTab.id
        }
        return newTab
    }

    public func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tabToClose = tabs[index]
        tabToClose.terminate()
        tabs.remove(at: index)

        if activeTabId == id {
            if index < tabs.count {
                activeTabId = tabs[index].id
            } else if let last = tabs.last {
                activeTabId = last.id
            } else {
                let fresh = createTab()
                activeTabId = fresh.id
            }
        }
    }

    public func selectTab(id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            activeTabId = id
        }
    }

    public func updateWorkingDirectoryIfNeeded(_ newPath: String) {
        self.workingDirectory = newPath
        for tab in tabs {
            tab.updateWorkingDirectoryIfNeeded(newPath)
        }
    }
}

/// 앱 내 모든 저장소의 다중 터미널 세션을 총괄 관리하는 싱글톤 매니저
public final class TerminalSessionManager: ObservableObject, @unchecked Sendable {
    public static let shared = TerminalSessionManager()

    @Published public var isPanelVisible: Bool = false
    @Published public var panelHeight: CGFloat = 270
    @Published public var isMaximized: Bool = false
    @Published public var activeRepositoryId: Int? = nil

    private var groups: [Int: RepositoryTerminalGroup] = [:]
    private let lock = NSLock()

    public init() {}

    public func getOrCreateGroup(for repositoryId: Int, name: String, localPath: String?) -> RepositoryTerminalGroup {
        lock.lock()
        defer { lock.unlock() }

        let resolvedPath = localPath ?? "~/Documents"

        if let existing = groups[repositoryId] {
            if let path = localPath {
                existing.updateWorkingDirectoryIfNeeded(path)
            }
            if existing.tabs.isEmpty {
                _ = existing.createTab()
            }
            return existing
        }

        let newGroup = RepositoryTerminalGroup(
            repositoryId: repositoryId,
            repositoryName: name,
            workingDirectory: resolvedPath
        )
        // 기본 터미널 탭 생성
        _ = newGroup.createTab()
        groups[repositoryId] = newGroup
        return newGroup
    }

    public func group(for repositoryId: Int) -> RepositoryTerminalGroup? {
        lock.lock()
        defer { lock.unlock() }
        return groups[repositoryId]
    }

    /// 하위 호환성 메서드 (기존 단일 세션 반환)
    public func getOrCreateSession(for repositoryId: Int, name: String, localPath: String?) -> RepositoryTerminalSession {
        let grp = getOrCreateGroup(for: repositoryId, name: name, localPath: localPath)
        return grp.activeTab ?? grp.createTab()
    }

    /// 하위 호환성 메서드
    public func session(for repositoryId: Int) -> RepositoryTerminalSession? {
        lock.lock()
        defer { lock.unlock() }
        return groups[repositoryId]?.activeTab
    }

    public func togglePanel(for repositoryId: Int? = nil, name: String? = nil, localPath: String? = nil) {
        if let repoId = repositoryId, let repoName = name {
            activeRepositoryId = repoId
            _ = getOrCreateGroup(for: repoId, name: repoName, localPath: localPath)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isPanelVisible.toggle()
        }
    }

    public func openPanel(for repositoryId: Int, name: String, localPath: String?) {
        activeRepositoryId = repositoryId
        _ = getOrCreateGroup(for: repositoryId, name: name, localPath: localPath)
        withAnimation(.easeInOut(duration: 0.2)) {
            isPanelVisible = true
        }
    }

    /// AI 에이전트 작업 실행 라우팅:
    /// 첫번째 작업을 A agent로 실행하다가 B agent로 신규 작업을 실행하거나,
    /// 현재 활성 탭이 이미 작업 중(isRunning)이거나 다른 프리셋일 경우 **새로운 탭을 자동 생성**하여 실행합니다.
    public func executeCommand(
        command: String,
        repositoryId: Int,
        name: String,
        localPath: String?,
        preset: AppSettings.AIAgentPreset? = nil
    ) {
        let group = getOrCreateGroup(for: repositoryId, name: name, localPath: localPath)
        openPanel(for: repositoryId, name: name, localPath: localPath)

        let targetTab: TerminalTabItem
        if let current = group.activeTab {
            // 새 탭 생성 조건:
            // 1. 현재 탭이 백그라운드에서 실행 중(isRunning)인 경우
            // 2. 현재 탭의 preset이 설정되어 있고, 이번 요청 preset과 다른 경우 (A agent 작업 후 B agent 작업 시 새 탭)
            // 3. 현재 탭이 이미 어떤 에이전트 작업을 수행한 적이 있고(hasExecutedTask), 이번 요청 프리셋과 불일치하는 경우
            if current.isRunning {
                targetTab = group.createTab(preset: preset, autoSelect: true)
            } else if let currentPreset = current.preset, let newPreset = preset, currentPreset != newPreset {
                targetTab = group.createTab(preset: newPreset, autoSelect: true)
            } else if current.hasExecutedTask && current.preset != preset {
                targetTab = group.createTab(preset: preset, autoSelect: true)
            } else {
                // 기존 유휴 탭 재사용
                if let p = preset {
                    current.preset = p
                    current.title = p.shortName
                }
                targetTab = current
            }
        } else {
            targetTab = group.createTab(preset: preset, autoSelect: true)
        }

        targetTab.hasExecutedTask = true
        group.activeTabId = targetTab.id

        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let targetPath = localPath ?? targetTab.workingDirectory
        let resolved = targetPath.replacingOccurrences(of: "~", with: home)
        let escapedDir = resolved.replacingOccurrences(of: "'", with: "'\\''")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let fullCommand: String
            if fileManager.fileExists(atPath: resolved) {
                fullCommand = "cd '\(escapedDir)' && \(command)"
            } else {
                fullCommand = command
            }
            targetTab.sendCommand(fullCommand)
            targetTab.terminalView.window?.makeFirstResponder(targetTab.terminalView)
        }
    }

    public func closeSession(for repositoryId: Int) {
        lock.lock()
        defer { lock.unlock() }
        if let grp = groups.removeValue(forKey: repositoryId) {
            for tab in grp.tabs {
                tab.terminate()
            }
        }
    }
}
