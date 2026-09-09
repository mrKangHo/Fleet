import Foundation
import SwiftUI

@MainActor
public final class SettingsViewModel: ObservableObject {
    private let environment: AppEnvironment

    @Published public var settings: AppSettings
    @Published public var isTestingToken: Bool = false
    @Published public var tokenTestResult: String?
    @Published public var isTokenValid: Bool?
    @Published public var hasRepoPermission: Bool?
    @Published public var notificationPermissionGranted: Bool = false

    public init(environment: AppEnvironment = .shared) {
        self.environment = environment
        let loaded = environment.settingsRepository.loadSettings()
        var currentSettings = loaded
        if !currentSettings.aiAgentPreset.isInstalled && currentSettings.aiAgentPreset != .custom {
            if let firstInstalled = AppSettings.AIAgentPreset.installedCases.first {
                currentSettings.aiAgentPreset = firstInstalled
                environment.settingsRepository.saveSettings(currentSettings)
            }
        }
        self.settings = currentSettings
    }

    public func save() {
        let oldSettings = environment.settingsRepository.loadSettings()
        // 토큰이 변경되거나 새로 등록된 경우, 저장소 선택 마법사가 먼저 뜨도록 초기화
        if oldSettings.githubToken != settings.githubToken {
            settings.hasCompletedInitialSelection = false
            settings.monitoredRepoIds = nil
            settings.ignoredRepoIds = []
        }
        environment.settingsRepository.saveSettings(settings)
        environment.terminalSessionManager.applyTerminalProfile(settings.terminalApp)
    }

    public func testToken() async {
        guard !settings.githubToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            tokenTestResult = "토큰을 입력해 주세요."
            isTokenValid = false
            hasRepoPermission = nil
            return
        }

        isTestingToken = true
        tokenTestResult = nil
        hasRepoPermission = nil

        do {
            let result = try await environment.githubRepository.validateTokenWithScopes(token: settings.githubToken)
            isTokenValid = true
            hasRepoPermission = result.hasRepoScope
            if result.hasRepoScope {
                tokenTestResult = "연동 성공! (\(result.username) 계정 - 비공개 저장소 조회 가능 ✅)"
            } else {
                tokenTestResult = "연동 성공 (\(result.username) 계정) ⚠️ 'repo' 권한이 없어 공개 저장소만 조회됩니다."
            }
            save()
        } catch {
            isTokenValid = false
            hasRepoPermission = nil
            tokenTestResult = "연동 실패: \(error.localizedDescription)"
        }

        isTestingToken = false
    }

    public func requestNotificationPermission() async {
        let granted = await environment.scheduleNotificationUseCase.requestPermission()
        self.notificationPermissionGranted = granted
        if granted {
            settings.isNotificationEnabled = true
            save()
        }
    }

    public var isMeloTTSInstalled: Bool {
        MeloTTSSpeechSynthesisService.isInstalled
    }

    public var availableKoreanVoices: [SpeechVoiceOption] {
        environment.speechSynthesisService(for: settings).availableVoices()
    }

    public func previewVoice() {
        environment.speechSynthesisService(for: settings).speak(
            "안녕하세요, Fleet입니다. 이렇게 안내해 드릴게요.",
            voiceIdentifier: settings.voiceIdentifier,
            rate: settings.voiceSpeechRate
        ) { }
    }

    public func rescanCLI() {
        AIAgentDiscovery.invalidateCache()
        objectWillChange.send()
    }

    public func resetDefaults() {
        let currentToken = settings.githubToken
        let currentMonitored = settings.monitoredRepoIds
        let currentIgnored = settings.ignoredRepoIds
        let currentCompleted = settings.hasCompletedInitialSelection

        var def = AppSettings.default
        def.githubToken = currentToken
        def.monitoredRepoIds = currentMonitored
        def.ignoredRepoIds = currentIgnored
        def.hasCompletedInitialSelection = currentCompleted

        self.settings = def
        save()
    }
}
