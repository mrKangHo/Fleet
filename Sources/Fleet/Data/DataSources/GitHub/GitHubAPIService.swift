import Foundation

public enum GitHubAPIError: LocalizedError, Sendable {
    case invalidURL
    case invalidToken
    case rateLimitExceeded
    case networkError(String)
    case decodingError(String)
    case unknown(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "유효하지 않은 요청 URL입니다."
        case .invalidToken:
            return "GitHub 토큰이 유효하지 않거나 만료되었습니다."
        case .rateLimitExceeded:
            return "GitHub API 호출 한도를 초과했습니다. 잠시 후 다시 시도해 주세요."
        case .networkError(let message):
            return "네트워크 오류: \(message)"
        case .decodingError(let message):
            return "데이터 파싱 오류: \(message)"
        case .unknown(let code):
            return "알 수 없는 오류 (HTTP 상태 코드: \(code))"
        }
    }
}

/// GitHub REST API v3 통신 서비스
public final class GitHubAPIService: Sendable {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.github.com")!

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Personal Access Token 유효성 검사 및 사용자 이름, 스코프 반환
    public func validateToken(token: String) async throws -> String {
        let (username, _) = try await validateTokenWithScopes(token: token)
        return username
    }

    /// Personal Access Token 유효성 검사 및 상세 정보(사용자명, repo 스코프 포함 여부) 반환
    public func validateTokenWithScopes(token: String) async throws -> (username: String, hasRepoScope: Bool) {
        let url = baseURL.appendingPathComponent("user")
        let request = makeRequest(url: url, token: token)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        do {
            let user = try JSONDecoder().decode(GitHubUserDTO.self, from: data)
            var hasRepo = false
            if let http = response as? HTTPURLResponse,
               let scopes = http.value(forHTTPHeaderField: "X-OAuth-Scopes") {
                let scopeList = scopes.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                hasRepo = scopeList.contains("repo")
            } else if token.starts(with: "github_pat_") {
                // Fine-grained 토큰은 X-OAuth-Scopes 헤더가 없으므로 true로 간주 (권한 설정 카드 안내)
                hasRepo = true
            }
            return (username: user.login, hasRepoScope: hasRepo)
        } catch {
            throw GitHubAPIError.decodingError(error.localizedDescription)
        }
    }

    /// 사용자의 모든 저장소 조회 (Public, Private, Org 포함)
    public func fetchUserRepositories(token: String) async throws -> [GitHubRepoDTO] {
        var allRepos: [GitHubRepoDTO] = []
        var page = 1
        let perPage = 100

        while page <= 10 { // 최대 1,000개까지 페이지네이션
            var components = URLComponents(url: baseURL.appendingPathComponent("user/repos"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "visibility", value: "all"),
                URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member"),
                URLQueryItem(name: "per_page", value: "\(perPage)"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "sort", value: "pushed"),
                URLQueryItem(name: "direction", value: "desc")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.invalidURL
            }

            let request = makeRequest(url: url, token: token)
            let (data, response) = try await session.data(for: request)
            try validateResponse(response)

            let repos: [GitHubRepoDTO]
            do {
                repos = try JSONDecoder().decode([GitHubRepoDTO].self, from: data)
            } catch {
                throw GitHubAPIError.decodingError(error.localizedDescription)
            }

            allRepos.append(contentsOf: repos)

            if repos.count < perPage {
                break
            }
            page += 1
        }

        return allRepos
    }

    /// 특정 저장소의 최신 커밋 정보 조회
    public func fetchLatestCommit(
        token: String,
        owner: String,
        repo: String,
        branch: String
    ) async throws -> (date: Date, message: String)? {
        var components = URLComponents(url: baseURL.appendingPathComponent("repos/\(owner)/\(repo)/commits"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "1"),
            URLQueryItem(name: "sha", value: branch)
        ]

        guard let url = components.url else { return nil }

        let request = makeRequest(url: url, token: token)
        guard let (data, response) = try? await session.data(for: request) else { return nil }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

        guard let commits = try? JSONDecoder().decode([GitHubCommitResponseDTO].self, from: data),
              let first = commits.first else {
            return nil
        }

        let message = first.commit.message
        let dateString = first.commit.committer?.date ?? first.commit.author?.date

        let date: Date
        if let dateString = dateString, let parsed = ISO8601DateFormatter().date(from: dateString) {
            date = parsed
        } else {
            date = Date()
        }

        return (date: date, message: message)
    }

    private func makeRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Fleet-macOS", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw GitHubAPIError.invalidToken
        case 403:
            throw GitHubAPIError.rateLimitExceeded
        default:
            throw GitHubAPIError.unknown(http.statusCode)
        }
    }
}
