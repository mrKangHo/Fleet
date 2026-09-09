import Foundation

/// 앱 전체 의존성 주입(DI) 컨테이너 (스레드 안전한 불변 인스턴스)
public final class AppEnvironment: Sendable {
    public static let shared = AppEnvironment()

    // MARK: - Repositories
    public let githubRepository: GitHubRepositoryProtocol
    public let memoRepository: MemoRepositoryProtocol
    public let settingsRepository: SettingsRepositoryProtocol
    public let localPathRepository: LocalPathRepositoryProtocol
    public let repositoryGuidelineRepository: RepositoryGuidelineRepositoryProtocol

    // MARK: - Services
    public let dockBadgeService: DockBadgeServiceProtocol
    public let notificationService: SystemNotificationServiceProtocol
    public let terminalExecutionService: TerminalExecutionServiceProtocol
    public let terminalSessionManager: TerminalSessionManager
    public let speechRecognitionService: SpeechRecognitionServiceProtocol
    public let speechSynthesisService: SpeechSynthesisServiceProtocol

    // MARK: - Use Cases
    public let fetchRepositoriesUseCase: FetchRepositoriesUseCase
    public let calculateStaleStatusUseCase: CalculateStaleStatusUseCase
    public let manageMemoUseCase: ManageMemoUseCase
    public let updateDockBadgeUseCase: UpdateDockBadgeUseCase
    public let scheduleNotificationUseCase: ScheduleNotificationUseCase
    public let executeAgentTaskUseCase: ExecuteAgentTaskUseCase
    public let manageRepositoryUseCase: ManageRepositoryUseCase
    public let manageRepositoryGuidelineUseCase: ManageRepositoryGuidelineUseCase
    public let manageVoiceCommandUseCase: ManageVoiceCommandUseCase

    public init(
        githubRepository: GitHubRepositoryProtocol = GitHubRepositoryImpl(),
        memoRepository: MemoRepositoryProtocol = MemoRepositoryImpl(),
        settingsRepository: SettingsRepositoryProtocol = SettingsRepositoryImpl(),
        localPathRepository: LocalPathRepositoryProtocol = LocalPathRepositoryImpl(),
        repositoryGuidelineRepository: RepositoryGuidelineRepositoryProtocol = RepositoryGuidelineRepositoryImpl(),
        dockBadgeService: DockBadgeServiceProtocol = DockBadgeManager(),
        notificationService: SystemNotificationServiceProtocol = NotificationManager(),
        terminalExecutionService: TerminalExecutionServiceProtocol = TerminalExecutionService(),
        terminalSessionManager: TerminalSessionManager = .shared,
        speechRecognitionService: SpeechRecognitionServiceProtocol = SpeechRecognitionService(),
        speechSynthesisService: SpeechSynthesisServiceProtocol = SpeechSynthesisService()
    ) {
        self.githubRepository = githubRepository
        self.memoRepository = memoRepository
        self.settingsRepository = settingsRepository
        self.localPathRepository = localPathRepository
        self.repositoryGuidelineRepository = repositoryGuidelineRepository
        self.dockBadgeService = dockBadgeService
        self.notificationService = notificationService
        self.terminalExecutionService = terminalExecutionService
        self.terminalSessionManager = terminalSessionManager
        self.speechRecognitionService = speechRecognitionService
        self.speechSynthesisService = speechSynthesisService

        let initialSettings = settingsRepository.loadSettings()
        terminalSessionManager.currentProfile = initialSettings.terminalApp

        let staleUseCase = CalculateStaleStatusUseCase()
        self.calculateStaleStatusUseCase = staleUseCase
        self.fetchRepositoriesUseCase = FetchRepositoriesUseCase(
            githubRepository: githubRepository,
            memoRepository: memoRepository
        )
        self.manageMemoUseCase = ManageMemoUseCase(memoRepository: memoRepository)
        self.updateDockBadgeUseCase = UpdateDockBadgeUseCase(
            badgeService: dockBadgeService,
            calculateStaleUseCase: staleUseCase
        )
        self.scheduleNotificationUseCase = ScheduleNotificationUseCase(
            notificationService: notificationService,
            calculateStaleUseCase: staleUseCase
        )
        self.executeAgentTaskUseCase = ExecuteAgentTaskUseCase(
            terminalService: terminalExecutionService,
            memoRepository: memoRepository
        )
        self.manageRepositoryUseCase = ManageRepositoryUseCase(
            githubRepository: githubRepository,
            settingsRepository: settingsRepository,
            localPathRepository: localPathRepository,
            memoRepository: memoRepository
        )
        self.manageRepositoryGuidelineUseCase = ManageRepositoryGuidelineUseCase(
            guidelineRepository: repositoryGuidelineRepository
        )
        self.manageVoiceCommandUseCase = ManageVoiceCommandUseCase()
    }
}
