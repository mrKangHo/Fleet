import Foundation
import SwiftUI
import AppKit
import SwiftTerm

/// 각 저장소별 독립 터미널 세션 모델
public final class RepositoryTerminalSession: ObservableObject, Identifiable, LocalProcessTerminalViewDelegate {
    public let id: Int // repositoryId
    public let repositoryName: String
    public var workingDirectory: String
    public let terminalView: LocalProcessTerminalView
    public let createdAt: Date

    @Published public var title: String
    @Published public var isRunning: Bool = false
    @Published public var exitCode: Int32? = nil

    public init(repositoryId: Int, repositoryName: String, workingDirectory: String) {
        self.id = repositoryId
        self.repositoryName = repositoryName
        self.workingDirectory = workingDirectory
        self.createdAt = Date()
        self.title = repositoryName

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

    // MARK: - LocalProcessTerminalViewDelegate
    public func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    public func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        DispatchQueue.main.async {
            if !title.isEmpty {
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

/// 앱 내 모든 저장소의 터미널 세션을 총괄 관리하는 싱글톤 매니저
public final class TerminalSessionManager: ObservableObject, @unchecked Sendable {
    public static let shared = TerminalSessionManager()

    @Published public var isPanelVisible: Bool = false
    @Published public var panelHeight: CGFloat = 260
    @Published public var isMaximized: Bool = false
    @Published public var activeRepositoryId: Int? = nil

    private var sessions: [Int: RepositoryTerminalSession] = [:]
    private let lock = NSLock()

    public init() {}

    public func getOrCreateSession(for repositoryId: Int, name: String, localPath: String?) -> RepositoryTerminalSession {
        lock.lock()
        defer { lock.unlock() }

        let resolvedPath = localPath ?? "~/Documents"

        if let existing = sessions[repositoryId] {
            if let path = localPath {
                existing.updateWorkingDirectoryIfNeeded(path)
            }
            return existing
        }

        let newSession = RepositoryTerminalSession(
            repositoryId: repositoryId,
            repositoryName: name,
            workingDirectory: resolvedPath
        )
        sessions[repositoryId] = newSession
        return newSession
    }

    public func session(for repositoryId: Int) -> RepositoryTerminalSession? {
        lock.lock()
        defer { lock.unlock() }
        return sessions[repositoryId]
    }

    public func togglePanel(for repositoryId: Int? = nil, name: String? = nil, localPath: String? = nil) {
        if let repoId = repositoryId, let repoName = name {
            activeRepositoryId = repoId
            _ = getOrCreateSession(for: repoId, name: repoName, localPath: localPath)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isPanelVisible.toggle()
        }
    }

    public func openPanel(for repositoryId: Int, name: String, localPath: String?) {
        activeRepositoryId = repositoryId
        _ = getOrCreateSession(for: repositoryId, name: name, localPath: localPath)
        withAnimation(.easeInOut(duration: 0.2)) {
            isPanelVisible = true
        }
    }

    public func executeCommand(command: String, repositoryId: Int, name: String, localPath: String?) {
        let session = getOrCreateSession(for: repositoryId, name: name, localPath: localPath)
        openPanel(for: repositoryId, name: name, localPath: localPath)

        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let targetPath = localPath ?? session.workingDirectory
        let resolved = targetPath.replacingOccurrences(of: "~", with: home)
        let escapedDir = resolved.replacingOccurrences(of: "'", with: "'\\''")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let fullCommand: String
            if fileManager.fileExists(atPath: resolved) {
                fullCommand = "cd '\(escapedDir)' && \(command)"
            } else {
                fullCommand = command
            }
            session.sendCommand(fullCommand)
            session.terminalView.window?.makeFirstResponder(session.terminalView)
        }
    }

    public func closeSession(for repositoryId: Int) {
        lock.lock()
        defer { lock.unlock() }
        if let s = sessions.removeValue(forKey: repositoryId) {
            s.terminalView.terminate()
        }
    }
}
