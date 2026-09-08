import Foundation

/// 저장소 로컬 폴더에 저장되는 AI 에이전트별 지침 파일 접근 프로토콜 (Domain Layer 인터페이스)
public protocol RepositoryGuidelineRepositoryProtocol: Sendable {
    /// 지침 파일의 전체 경로를 반환합니다.
    func guidelineFilePath(localPath: String, preset: AppSettings.AIAgentPreset) -> String

    /// 지침 파일 내용을 읽습니다. 파일이 없으면 nil을 반환합니다.
    func loadGuideline(localPath: String, preset: AppSettings.AIAgentPreset) -> String?

    /// 지침 파일을 저장(생성 또는 덮어쓰기)합니다.
    func saveGuideline(localPath: String, preset: AppSettings.AIAgentPreset, content: String) throws

    /// 지침 파일이 이미 존재하는지 확인합니다.
    func guidelineExists(localPath: String, preset: AppSettings.AIAgentPreset) -> Bool
}
