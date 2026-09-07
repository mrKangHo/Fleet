import Foundation
import AppKit

public enum TerminalExecutionError: LocalizedError, Sendable {
    case scriptExecutionFailed(String)
    case directoryNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .scriptExecutionFailed(let message):
            return "터미널 실행 실패: \(message)"
        case .directoryNotFound(let path):
            return "로컬 작업 디렉토리를 찾을 수 없습니다: \(path)"
        }
    }
}

/// macOS 네이티브 터미널 자동 실행 서비스 (AppleScript 연동)
public final class TerminalExecutionService: TerminalExecutionServiceProtocol, Sendable {
    public init() {}

    public func executeScript(scriptContent: String, workingDirectory: String? = nil, terminalApp: AppSettings.TerminalApp) throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("workmanager_tasks", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let scriptFileName = "task_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).command"
        let scriptUrl = tempDir.appendingPathComponent(scriptFileName)

        let finalScript: String
        if scriptContent.contains("#!/bin/zsh") {
            finalScript = """
            \(scriptContent)
            exec /bin/zsh
            """
        } else {
            finalScript = """
            #!/bin/zsh
            export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$HOME/.local/bin:$PATH"
            [ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile"
            [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"

            \(scriptContent)
            exec /bin/zsh
            """
        }

        try finalScript.write(to: scriptUrl, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptUrl.path)

        let appName = resolveTerminalAppName(for: terminalApp)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName, scriptUrl.path]

        do {
            try process.run()
        } catch {
            throw TerminalExecutionError.scriptExecutionFailed("터미널 앱 실행 실패: \(error.localizedDescription)")
        }
    }

    public func executeInTerminal(command: String, workingDirectory: String, terminalApp: AppSettings.TerminalApp) throws {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let resolvedPath = workingDirectory.replacingOccurrences(of: "~", with: home)

        guard fileManager.fileExists(atPath: resolvedPath) else {
            throw TerminalExecutionError.directoryNotFound(resolvedPath)
        }

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("workmanager_tasks", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let scriptFileName = "task_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).command"
        let scriptUrl = tempDir.appendingPathComponent(scriptFileName)

        let scriptContent = """
        #!/bin/zsh
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$HOME/.local/bin:$PATH"
        [ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile"
        [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"

        cd \(escapeForShell(resolvedPath)) || {
            echo "❌ 디렉토리 이동 실패: \(resolvedPath)"
            exit 1
        }
        clear
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🚀 [Fleet] AI Agent 작업 실행"
        echo "📂 작업 위치: \(resolvedPath)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        \(command)
        exec /bin/zsh
        """

        try scriptContent.write(to: scriptUrl, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptUrl.path)

        let appName = resolveTerminalAppName(for: terminalApp)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName, scriptUrl.path]

        do {
            try process.run()
        } catch {
            throw TerminalExecutionError.scriptExecutionFailed("터미널 앱 실행 실패: \(error.localizedDescription)")
        }
    }

    private func resolveTerminalAppName(for terminalApp: AppSettings.TerminalApp) -> String {
        switch terminalApp {
        case .embedded, .terminal:
            return "Terminal"
        case .iTerm:
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalApp.bundleIdentifier) != nil {
                return "iTerm"
            }
            return "Terminal"
        case .ghostty:
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalApp.bundleIdentifier) != nil {
                return "Ghostty"
            }
            return "Terminal"
        }
    }

    private func escapeForAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func escapeForShell(_ path: String) -> String {
        return "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
