import Foundation

/// 터미널 실행 서비스 프로토콜 (Domain Layer 인터페이스)
public protocol TerminalExecutionServiceProtocol: Sendable {
    /// 지정된 로컬 작업 디렉토리에서 AI 명령어를 실행하도록 터미널을 열고 명령어를 전달합니다.
    func executeInTerminal(command: String, workingDirectory: String, terminalApp: AppSettings.TerminalApp) throws

    /// 안전한 셸 런처 스크립트 전문을 터미널에서 실행합니다.
    func executeScript(scriptContent: String, workingDirectory: String?, terminalApp: AppSettings.TerminalApp) throws
}

public extension TerminalExecutionServiceProtocol {
    func executeScript(scriptContent: String, terminalApp: AppSettings.TerminalApp) throws {
        try executeScript(scriptContent: scriptContent, workingDirectory: nil, terminalApp: terminalApp)
    }
}
