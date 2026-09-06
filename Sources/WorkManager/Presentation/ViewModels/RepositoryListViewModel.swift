import Foundation
import SwiftUI

@MainActor
public final class RepositoryListViewModel: ObservableObject {
    private let environment: AppEnvironment

    // MARK: - Filter & Sort Enums
    public enum FilterType: String, CaseIterable, Identifiable {
        case all = "관리 중"
        case stale = "방치됨 🔴"
        case warning = "주의 🟡"
        case withMemos = "메모 있음 📝"
        case ignored = "관리 제외됨 🚫"

        public var id: String { rawValue }
    }

    public enum SortOption: String, CaseIterable, Identifiable {
        case elapsedDesc = "오래 방치된 순"
        case elapsedAsc = "최근 활동 순"
        case nameAsc = "이름 순 (A-Z)"
        case starsDesc = "스타 많은 순"

        public var id: String { rawValue }
    }

    // MARK: - Published State
    @Published public var allFetchedRepositories: [RepositoryItem] = []
    @Published public var repositories: [RepositoryItem] = []
    @Published public var selectedRepositoryId: Int?
    @Published public var searchQuery: String = ""
    @Published public var selectedFilter: FilterType = .all
    @Published public var selectedSort: SortOption = .elapsedDesc

    @Published public var isLoading: Bool = false
    @Published public var isSelectionSheetPresented: Bool = false
    @Published public var errorMessage: String?
    @Published public var currentSettings: AppSettings = .default
    @Published public var authenticatedUser: String?

    public init(environment: AppEnvironment = .shared) {
        self.environment = environment
        self.currentSettings = environment.settingsRepository.loadSettings()
    }

    // MARK: - Computed Filtered List
    public var filteredRepositories: [RepositoryItem] {
        var list: [RepositoryItem]
        if selectedFilter == .ignored {
            list = allFetchedRepositories.filter { !currentSettings.isRepoMonitored($0.id) }
        } else {
            list = repositories
        }

        // 1. 검색어 필터링
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchQuery.lowercased()
            list = list.filter { repo in
                repo.name.lowercased().contains(query) ||
                (repo.description?.lowercased().contains(query) ?? false) ||
                (repo.language?.lowercased().contains(query) ?? false)
            }
        }

        // 2. 필터 타입 적용
        switch selectedFilter {
        case .all, .ignored:
            break
        case .stale:
            list = list.filter { repo in
                let status = environment.calculateStaleStatusUseCase.execute(
                    latestDate: repo.latestActivityDate,
                    warningThreshold: currentSettings.warningThresholdDays,
                    staleThreshold: currentSettings.staleThresholdDays
                )
                return status.isStale
            }
        case .warning:
            list = list.filter { repo in
                let status = environment.calculateStaleStatusUseCase.execute(
                    latestDate: repo.latestActivityDate,
                    warningThreshold: currentSettings.warningThresholdDays,
                    staleThreshold: currentSettings.staleThresholdDays
                )
                if case .warning = status { return true }
                return false
            }
        case .withMemos:
            list = list.filter { $0.memoCount > 0 }
        }

        // 3. 정렬 적용
        switch selectedSort {
        case .elapsedDesc:
            list.sort { (r1, r2) -> Bool in
                let d1 = r1.latestActivityDate ?? .distantPast
                let d2 = r2.latestActivityDate ?? .distantPast
                return d1 < d2 // 오래된 것이 위로
            }
        case .elapsedAsc:
            list.sort { (r1, r2) -> Bool in
                let d1 = r1.latestActivityDate ?? .distantPast
                let d2 = r2.latestActivityDate ?? .distantPast
                return d1 > d2 // 최신이 위로
            }
        case .nameAsc:
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .starsDesc:
            list.sort { $0.stargazersCount > $1.stargazersCount }
        }

        return list
    }

    /// 방치된 저장소 개수 (관리 대상 저장소 기준)
    public var staleCount: Int {
        repositories.filter { repo in
            let status = environment.calculateStaleStatusUseCase.execute(
                latestDate: repo.latestActivityDate,
                warningThreshold: currentSettings.warningThresholdDays,
                staleThreshold: currentSettings.staleThresholdDays
            )
            return status.isStale
        }.count
    }

    /// 관리 제외된 저장소 개수
    public var ignoredCount: Int {
        allFetchedRepositories.filter { !currentSettings.isRepoMonitored($0.id) }.count
    }

    /// 저장소 상태 계산 헬퍼
    public func staleStatus(for repo: RepositoryItem) -> StaleStatus {
        environment.calculateStaleStatusUseCase.execute(
            latestDate: repo.latestActivityDate,
            warningThreshold: currentSettings.warningThresholdDays,
            staleThreshold: currentSettings.staleThresholdDays
        )
    }

    // MARK: - Actions
    public func loadSettings() {
        self.currentSettings = environment.settingsRepository.loadSettings()
    }

    public func refreshRepositories(silentIfNoToken: Bool = false) async {
        loadSettings()
        guard !currentSettings.githubToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if !silentIfNoToken {
                self.errorMessage = "GitHub Personal Access Token이 등록되지 않았습니다. 설정에서 토큰을 입력해 주세요."
            }
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let token = currentSettings.githubToken
            // 1. 토큰 검증 및 사용자 확인
            self.authenticatedUser = try await environment.githubRepository.validateToken(token: token)

            // 2. 저장소 전체 목록 로드
            let allRepos = try await environment.fetchRepositoriesUseCase.execute(
                token: token,
                settings: currentSettings
            )
            self.allFetchedRepositories = allRepos

            // 3. 첫 동기화 시: 사이드바에 저장소를 미리 띄우지 않고 선택 팝업을 먼저 표시!
            if !currentSettings.hasCompletedInitialSelection && !allRepos.isEmpty {
                self.repositories = []
                self.selectedRepositoryId = nil
                self.isSelectionSheetPresented = true
            } else {
                // 이미 초기 선택을 완료한 경우에만 사이드바에 저장소 목록 표시
                applyMonitoringFilters()
            }

        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 관리 설정 반영
    public func applyMonitoringFilters() {
        self.repositories = allFetchedRepositories.filter { currentSettings.isRepoMonitored($0.id) }

        // 첫 번째 저장소 자동 선택
        if selectedRepositoryId == nil || !repositories.contains(where: { $0.id == selectedRepositoryId }) {
            selectedRepositoryId = repositories.first?.id
        }

        // Dock 뱃지 및 알림 갱신 (관리 대상 기준)
        environment.updateDockBadgeUseCase.execute(
            repositories: repositories,
            settings: currentSettings
        )

        Task {
            await environment.scheduleNotificationUseCase.execute(
                repositories: repositories,
                settings: currentSettings
            )
        }
    }

    /// 선택 마법사에서 선택된 저장소 저장
    public func saveSelectedRepositories(selectedIds: Set<Int>) {
        currentSettings.monitoredRepoIds = selectedIds
        // 선택되지 않은 ID는 ignored로 등록
        let allIds = Set(allFetchedRepositories.map { $0.id })
        currentSettings.ignoredRepoIds = allIds.subtracting(selectedIds)
        currentSettings.hasCompletedInitialSelection = true
        environment.settingsRepository.saveSettings(currentSettings)
        applyMonitoringFilters()
    }

    /// 특정 저장소 관리 제외(숨기기)
    public func ignoreRepository(repoId: Int) {
        currentSettings.ignoredRepoIds.insert(repoId)
        if currentSettings.monitoredRepoIds != nil {
            currentSettings.monitoredRepoIds?.remove(repoId)
        }
        environment.settingsRepository.saveSettings(currentSettings)
        applyMonitoringFilters()
    }

    /// 관리 제외된 저장소를 다시 관리 목록으로 복구
    public func restoreRepository(repoId: Int) {
        currentSettings.ignoredRepoIds.remove(repoId)
        if currentSettings.monitoredRepoIds != nil {
            currentSettings.monitoredRepoIds?.insert(repoId)
        }
        environment.settingsRepository.saveSettings(currentSettings)
        applyMonitoringFilters()
    }

    /// 메모 개수 변경 시 로컬 목록 갱신
    public func updateMemoCount(for repositoryId: Int, count: Int) {
        if let idx = allFetchedRepositories.firstIndex(where: { $0.id == repositoryId }) {
            allFetchedRepositories[idx].memoCount = count
        }
        if let idx = repositories.firstIndex(where: { $0.id == repositoryId }) {
            repositories[idx].memoCount = count
        }
    }
}
