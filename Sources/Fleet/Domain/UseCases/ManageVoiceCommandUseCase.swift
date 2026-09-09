import Foundation

/// 음성 발화 텍스트를 의도로 해석하고, 이미 로드된 데이터로 응답 문장을 조립하는 Use Case
public struct ManageVoiceCommandUseCase: Sendable {
    public init() {}

    // MARK: - Intent Parsing

    public func parseIntent(from text: String) -> VoiceIntent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unrecognized(raw: text) }

        if trimmed.contains("도움말") || trimmed.contains("뭐 할 수 있어") || trimmed.contains("명령어") {
            return .help
        }

        if trimmed.contains("브리핑") || (trimmed.contains("오늘") && trimmed.contains("상황")) {
            return .briefing
        }

        if trimmed.contains("열어") || trimmed.contains("이동") {
            let name = extractRepositoryName(from: trimmed, trailingKeywords: ["열어줘", "열어", "이동해줘", "이동"])
            if !name.isEmpty {
                return .openRepository(name: name)
            }
        }

        if trimmed.contains("메모") && (trimmed.contains("현황") || trimmed.contains("개수") || trimmed.contains("몇")) {
            let name = extractRepositoryName(from: trimmed, trailingKeywords: ["메모", "현황", "개수", "몇", "알려줘", "말해줘"])
            return .memoSummary(name: name.isEmpty ? nil : name)
        }

        if trimmed.contains("상태") {
            let name = extractRepositoryName(from: trimmed, trailingKeywords: ["상태", "알려줘", "말해줘", "어때"])
            return .repositoryStatus(name: name.isEmpty ? nil : name)
        }

        return .unrecognized(raw: trimmed)
    }

    /// 발화에서 뒤쪽 동사/키워드를 제거하고 남는 앞부분을 저장소 이름 후보로 추출합니다.
    private func extractRepositoryName(from text: String, trailingKeywords: [String]) -> String {
        var candidate = text
        for keyword in trailingKeywords {
            if let range = candidate.range(of: keyword) {
                candidate = String(candidate[candidate.startIndex..<range.lowerBound])
            }
        }
        let particlesTrimmed = candidate
            .trimmingCharacters(in: .whitespaces)
            .trimmingSuffix("저장소")
            .trimmingSuffix("를")
            .trimmingSuffix("을")
            .trimmingCharacters(in: .whitespaces)
        return particlesTrimmed
    }

    // MARK: - Response Building

    public func buildBriefing(statuses: [(repository: RepositoryItem, status: StaleStatus)], pendingMemoCount: Int) -> String {
        let staleCount = statuses.filter { $0.status.isStale }.count
        guard staleCount > 0 else {
            return "방치된 저장소는 없습니다. 대기 중인 메모는 \(pendingMemoCount)개입니다."
        }

        let mostStale = statuses
            .filter { $0.status.isStale }
            .max { $0.status.elapsedDays < $1.status.elapsedDays }

        var text = "방치된 저장소 \(staleCount)개입니다."
        if let mostStale = mostStale {
            text += " \(mostStale.repository.name)가 \(mostStale.status.elapsedDays)일째로 가장 오래됐습니다."
        }
        text += " 대기 중인 메모는 \(pendingMemoCount)개입니다."
        return text
    }

    public func buildRepositoryStatus(repository: RepositoryItem, status: StaleStatus) -> String {
        "\(repository.name)는 \(status.description) 상태입니다."
    }

    public func buildMemoSummary(memos: [MemoItem]) -> String {
        guard !memos.isEmpty else { return "등록된 메모가 없습니다." }
        let pending = memos.filter { $0.status == .pending }.count
        let inProgress = memos.filter { $0.status == .inProgress }.count
        let completed = memos.filter { $0.status == .completed }.count
        return "대기 \(pending)개, 작업 중 \(inProgress)개, 완료 \(completed)개입니다."
    }

    public func buildRepositoryNotFound(name: String) -> String {
        "\(name) 저장소를 찾지 못했습니다."
    }

    public func helpText() -> String {
        "브리핑해줘, 저장소 이름 열어줘, 상태 알려줘, 메모 현황 알려줘 라고 말씀해 보세요."
    }
}

private extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
