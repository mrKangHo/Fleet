import Foundation

/// GitHub 데이터 접근 프로토콜 (Domain Layer 인터페이스)
public protocol GitHubRepositoryProtocol: Sendable {
    /// 사용자의 모든 저장소(Public, Private, Org 포함)를 가져옵니다.
    func fetchRepositories(token: String) async throws -> [RepositoryItem]
    
    /// 특정 저장소의 최신 커밋 정보를 가져옵니다.
    func fetchLatestCommit(token: String, owner: String, repo: String, branch: String) async throws -> (date: Date, message: String)?
    
    /// 사용자 토큰 유효성 및 로그인 계정명을 확인합니다.
    func validateToken(token: String) async throws -> String

    /// 사용자 토큰 유효성, 계정명, repo 권한 유무를 상세 확인합니다.
    func validateTokenWithScopes(token: String) async throws -> (username: String, hasRepoScope: Bool)
}
