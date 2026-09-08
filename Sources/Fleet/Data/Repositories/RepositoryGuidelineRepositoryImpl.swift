import Foundation

/// RepositoryGuidelineRepositoryProtocol 구현체 (로컬 파일 시스템 기반)
public final class RepositoryGuidelineRepositoryImpl: RepositoryGuidelineRepositoryProtocol, @unchecked Sendable {
    private let fileManager: FileManager
    private let commonGuidelineFileName = ".fleet-common-guideline.md"

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func guidelineFilePath(localPath: String, preset: AppSettings.AIAgentPreset) -> String {
        (localPath as NSString).appendingPathComponent(preset.guidelineFileName)
    }

    public func loadGuideline(localPath: String, preset: AppSettings.AIAgentPreset) -> String? {
        let path = guidelineFilePath(localPath: localPath, preset: preset)
        guard fileManager.fileExists(atPath: path) else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    public func saveGuideline(localPath: String, preset: AppSettings.AIAgentPreset, content: String) throws {
        let path = guidelineFilePath(localPath: localPath, preset: preset)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    public func guidelineExists(localPath: String, preset: AppSettings.AIAgentPreset) -> Bool {
        fileManager.fileExists(atPath: guidelineFilePath(localPath: localPath, preset: preset))
    }

    public func commonGuidelineFilePath(localPath: String) -> String {
        (localPath as NSString).appendingPathComponent(commonGuidelineFileName)
    }

    public func loadCommonGuideline(localPath: String) -> String? {
        let path = commonGuidelineFilePath(localPath: localPath)
        guard fileManager.fileExists(atPath: path) else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    public func saveCommonGuideline(localPath: String, content: String) throws {
        try content.write(toFile: commonGuidelineFilePath(localPath: localPath), atomically: true, encoding: .utf8)
    }

    public func commonGuidelineExists(localPath: String) -> Bool {
        fileManager.fileExists(atPath: commonGuidelineFilePath(localPath: localPath))
    }
}
