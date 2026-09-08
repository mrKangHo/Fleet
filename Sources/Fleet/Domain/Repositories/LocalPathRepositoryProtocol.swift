import Foundation

/// 저장소별 로컬 파일 경로 매핑 및 자동 탐색 프로토콜
public protocol LocalPathRepositoryProtocol: Sendable {
    func getLocalPath(for repositoryId: Int) -> String?
    func setLocalPath(_ path: String, for repositoryId: Int)
    func removeLocalPath(for repositoryId: Int)
    func detectLocalPath(for repoName: String, baseDirectories: [String]) -> String?
}
