import Foundation

/// LocalPathRepositoryProtocol 구현체 (UserDefaults 기반 영속화 및 파일 시스템 자동 감지)
public final class LocalPathRepositoryImpl: LocalPathRepositoryProtocol, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key = "workmanager_local_repo_paths"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func getLocalPath(for repositoryId: Int) -> String? {
        let dict = userDefaults.dictionary(forKey: key) as? [String: String] ?? [:]
        return dict["\(repositoryId)"]
    }

    public func setLocalPath(_ path: String, for repositoryId: Int) {
        var dict = userDefaults.dictionary(forKey: key) as? [String: String] ?? [:]
        dict["\(repositoryId)"] = path
        userDefaults.set(dict, forKey: key)
    }

    public func removeLocalPath(for repositoryId: Int) {
        var dict = userDefaults.dictionary(forKey: key) as? [String: String] ?? [:]
        dict.removeValue(forKey: "\(repositoryId)")
        userDefaults.set(dict, forKey: key)
    }

    public func detectLocalPath(for repoName: String, baseDirectories: [String]) -> String? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path

        for base in baseDirectories {
            let expandedBase = base.replacingOccurrences(of: "~", with: home)
            let candidate = (expandedBase as NSString).appendingPathComponent(repoName)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: candidate, isDirectory: &isDir), isDir.boolValue {
                return candidate
            }
        }
        return nil
    }
}
