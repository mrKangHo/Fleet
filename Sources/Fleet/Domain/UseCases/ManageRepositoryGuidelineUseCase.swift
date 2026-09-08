import Foundation

/// 저장소 × AI 에이전트별 지침 파일 조회/저장과, 모든 AI가 공유하는 공통 지침의 반영을 담당하는 Use Case
public struct ManageRepositoryGuidelineUseCase: Sendable {
    private static let commonBlockStart = "<!-- FLEET:COMMON-GUIDELINE:START -->"
    private static let commonBlockEnd = "<!-- FLEET:COMMON-GUIDELINE:END -->"

    private let guidelineRepository: RepositoryGuidelineRepositoryProtocol

    public init(guidelineRepository: RepositoryGuidelineRepositoryProtocol) {
        self.guidelineRepository = guidelineRepository
    }

    public func filePath(localPath: String, preset: AppSettings.AIAgentPreset) -> String {
        guidelineRepository.guidelineFilePath(localPath: localPath, preset: preset)
    }

    /// 해당 AI 에이전트 전용 지침(공통 지침 블록은 제외)을 읽습니다.
    public func loadGuideline(localPath: String, preset: AppSettings.AIAgentPreset) -> String {
        let raw = guidelineRepository.loadGuideline(localPath: localPath, preset: preset) ?? ""
        return Self.stripCommonBlock(from: raw)
    }

    /// 해당 AI 에이전트 전용 지침을 저장합니다. 기존에 저장된 공통 지침은 그대로 유지되어 함께 기록됩니다.
    public func saveGuideline(localPath: String, preset: AppSettings.AIAgentPreset, specificContent: String) throws {
        let common = guidelineRepository.loadCommonGuideline(localPath: localPath) ?? ""
        let merged = Self.mergeCommonBlock(common: common, specific: specificContent)
        try guidelineRepository.saveGuideline(localPath: localPath, preset: preset, content: merged)
    }

    public func guidelineExists(localPath: String, preset: AppSettings.AIAgentPreset) -> Bool {
        guidelineRepository.guidelineExists(localPath: localPath, preset: preset)
    }

    public func commonGuidelineFilePath(localPath: String) -> String {
        guidelineRepository.commonGuidelineFilePath(localPath: localPath)
    }

    public func loadCommonGuideline(localPath: String) -> String {
        guidelineRepository.loadCommonGuideline(localPath: localPath) ?? ""
    }

    public func commonGuidelineExists(localPath: String) -> Bool {
        guidelineRepository.commonGuidelineExists(localPath: localPath)
    }

    /// 공통 지침을 저장하고, 모든 AI 에이전트별 지침 파일 상단에 즉시 반영합니다.
    /// 각 파일의 기존 에이전트 전용 내용은 그대로 보존됩니다.
    public func saveCommonGuideline(localPath: String, content: String) throws {
        try guidelineRepository.saveCommonGuideline(localPath: localPath, content: content)

        for preset in AppSettings.AIAgentPreset.allCases {
            let existingRaw = guidelineRepository.loadGuideline(localPath: localPath, preset: preset) ?? ""
            let specificOnly = Self.stripCommonBlock(from: existingRaw)
            let merged = Self.mergeCommonBlock(common: content, specific: specificOnly)
            try guidelineRepository.saveGuideline(localPath: localPath, preset: preset, content: merged)
        }
    }

    // MARK: - Common Block Merge Helpers

    private static func mergeCommonBlock(common: String, specific: String) -> String {
        let trimmedCommon = common.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSpecific = specific.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCommon.isEmpty else { return trimmedSpecific }

        let block = "\(commonBlockStart)\n\(trimmedCommon)\n\(commonBlockEnd)"
        guard !trimmedSpecific.isEmpty else { return block }
        return "\(block)\n\n\(trimmedSpecific)"
    }

    private static func stripCommonBlock(from content: String) -> String {
        guard let startRange = content.range(of: commonBlockStart),
              let endRange = content.range(of: commonBlockEnd),
              startRange.lowerBound < endRange.upperBound else {
            return content
        }
        var result = content
        result.removeSubrange(startRange.lowerBound..<endRange.upperBound)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
