import Foundation

/// 저장소 × AI 에이전트별 지침 파일 조회/저장을 담당하는 Use Case
public struct ManageRepositoryGuidelineUseCase: Sendable {
    private let guidelineRepository: RepositoryGuidelineRepositoryProtocol

    public init(guidelineRepository: RepositoryGuidelineRepositoryProtocol) {
        self.guidelineRepository = guidelineRepository
    }

    public func filePath(localPath: String, preset: AppSettings.AIAgentPreset) -> String {
        guidelineRepository.guidelineFilePath(localPath: localPath, preset: preset)
    }

    public func loadGuideline(localPath: String, preset: AppSettings.AIAgentPreset) -> String? {
        guidelineRepository.loadGuideline(localPath: localPath, preset: preset)
    }

    public func saveGuideline(localPath: String, preset: AppSettings.AIAgentPreset, content: String) throws {
        try guidelineRepository.saveGuideline(localPath: localPath, preset: preset, content: content)
    }

    public func guidelineExists(localPath: String, preset: AppSettings.AIAgentPreset) -> Bool {
        guidelineRepository.guidelineExists(localPath: localPath, preset: preset)
    }
}
