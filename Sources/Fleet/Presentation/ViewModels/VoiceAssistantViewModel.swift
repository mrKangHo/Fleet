import Foundation
import SwiftUI

@MainActor
public final class VoiceAssistantViewModel: ObservableObject {
    public enum State: Equatable {
        case idle
        case listening
        case thinking
        case speaking
        case error(String)
    }

    private let environment: AppEnvironment
    private let listViewModel: RepositoryListViewModel
    private let detailViewModel: RepositoryDetailViewModel

    @Published public var state: State = .idle
    @Published public var transcript: String = ""
    @Published public var responseText: String = ""
    @Published public var isOverlayPresented: Bool = false

    public init(
        environment: AppEnvironment,
        listViewModel: RepositoryListViewModel,
        detailViewModel: RepositoryDetailViewModel
    ) {
        self.environment = environment
        self.listViewModel = listViewModel
        self.detailViewModel = detailViewModel
    }

    public func toggleListening() {
        isOverlayPresented = true

        if state == .listening {
            environment.speechRecognitionService.stopListening()
            state = .idle
            return
        }

        transcript = ""
        responseText = ""

        Task {
            let authorized = await environment.speechRecognitionService.requestAuthorization()
            guard authorized else {
                self.state = .error("마이크 또는 음성 인식 권한이 필요합니다. 시스템 설정에서 권한을 허용해 주세요.")
                return
            }
            self.startListening()
        }
    }

    private func startListening() {
        state = .listening
        environment.speechRecognitionService.startListening(
            onPartialResult: { [weak self] text in
                self?.transcript = text
            },
            onFinalResult: { [weak self] text in
                self?.handleFinalTranscript(text)
            },
            onError: { [weak self] error in
                self?.state = .error(error.localizedDescription)
            }
        )
    }

    private func handleFinalTranscript(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .idle
            return
        }

        state = .thinking
        Task {
            let intent = await resolveIntent(from: text)
            let response = self.buildResponse(for: intent)
            self.respond(with: response)
        }
    }

    private func resolveIntent(from text: String) async -> VoiceIntent {
        let settings = environment.settingsRepository.loadSettings()
        if settings.naturalLanguageVoiceCommands, environment.voiceIntentClassifierService.isAvailable {
            let repoNames = listViewModel.repositories.map { $0.name }
            if let classified = await environment.voiceIntentClassifierService.classify(text: text, repositoryNames: repoNames) {
                return classified
            }
        }
        return environment.manageVoiceCommandUseCase.parseIntent(from: text)
    }

    private func buildResponse(for intent: VoiceIntent) -> String {
        let useCase = environment.manageVoiceCommandUseCase

        switch intent {
        case .briefing:
            let statuses = listViewModel.repositories.map { repo in
                (repository: repo, status: listViewModel.staleStatus(for: repo))
            }
            let pendingMemoCount = listViewModel.repositories.reduce(0) { $0 + $1.memoCount }
            return useCase.buildBriefing(statuses: statuses, pendingMemoCount: pendingMemoCount)

        case .openRepository(let name):
            guard let match = findRepository(named: name) else {
                return useCase.buildRepositoryNotFound(name: name)
            }
            listViewModel.selectedRepositoryId = match.id
            return "\(match.name) 저장소를 열었습니다."

        case .repositoryStatus(let name):
            guard let repo = resolveRepository(named: name) else {
                return name.map { useCase.buildRepositoryNotFound(name: $0) } ?? "먼저 저장소를 선택해 주세요."
            }
            let status = listViewModel.staleStatus(for: repo)
            return useCase.buildRepositoryStatus(repository: repo, status: status)

        case .memoSummary(let name):
            if let name = name {
                guard let repo = findRepository(named: name) else {
                    return useCase.buildRepositoryNotFound(name: name)
                }
                guard repo.id == detailViewModel.repository?.id else {
                    return "\(repo.name)를 먼저 열어 주시면 메모 현황을 알려드릴게요."
                }
                return useCase.buildMemoSummary(memos: detailViewModel.memos)
            }
            guard detailViewModel.repository != nil else {
                return "먼저 저장소를 선택해 주세요."
            }
            return useCase.buildMemoSummary(memos: detailViewModel.memos)

        case .help:
            return useCase.helpText()

        case .unrecognized:
            return "죄송해요, 이해하지 못했습니다. " + useCase.helpText()
        }
    }

    private func resolveRepository(named name: String?) -> RepositoryItem? {
        guard let name = name, !name.isEmpty else {
            return detailViewModel.repository
        }
        return findRepository(named: name)
    }

    private func findRepository(named name: String) -> RepositoryItem? {
        let query = name.lowercased()
        return listViewModel.repositories.first { $0.name.lowercased().contains(query) }
    }

    private func respond(with text: String) {
        responseText = text
        state = .speaking
        let settings = environment.settingsRepository.loadSettings()
        environment.speechSynthesisService(for: settings).speak(
            text,
            voiceIdentifier: settings.voiceIdentifier,
            rate: settings.voiceSpeechRate
        ) { [weak self] in
            Task { @MainActor in
                guard let self = self, self.state == .speaking else { return }
                self.state = .idle
            }
        }
    }

    public func dismissOverlay() {
        environment.speechRecognitionService.stopListening()
        let settings = environment.settingsRepository.loadSettings()
        environment.speechSynthesisService(for: settings).stopSpeaking()
        state = .idle
        isOverlayPresented = false
    }
}
