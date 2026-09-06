import SwiftUI

public struct MainSplitView: View {
    @StateObject private var listViewModel: RepositoryListViewModel
    @StateObject private var detailViewModel: RepositoryDetailViewModel
    @State private var isSettingsPresented = false

    public init(environment: AppEnvironment = .shared) {
        self._listViewModel = StateObject(wrappedValue: RepositoryListViewModel(environment: environment))
        self._detailViewModel = StateObject(wrappedValue: RepositoryDetailViewModel(environment: environment))
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: listViewModel,
                isSettingsPresented: $isSettingsPresented
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            RepositoryDetailView(
                viewModel: detailViewModel,
                onMemoCountChanged: { newCount in
                    if let repoId = detailViewModel.repository?.id {
                        listViewModel.updateMemoCount(for: repoId, count: newCount)
                    }
                }
            )
            .navigationTitle(detailViewModel.repository?.name ?? "WorkManager")
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView {
                // 설정 창이 완전히 닫힌 후 저장소 동기화 시작 (시트 애니메이션 충돌 방지)
                Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    await listViewModel.refreshRepositories()
                }
            }
        }
        .sheet(isPresented: $listViewModel.isSelectionSheetPresented) {
            RepositorySelectionSheet(viewModel: listViewModel)
        }
        .onChange(of: listViewModel.selectedRepositoryId) { _, newId in
            if let newId = newId,
               let repo = listViewModel.repositories.first(where: { $0.id == newId }) {
                detailViewModel.setRepository(repo)
            } else {
                detailViewModel.setRepository(nil)
            }
        }
        .task {
            // 앱 구동 시: 토큰 미등록이면 환경설정 시트 바로 표시, 토큰 있으면 저장소 동기화
            listViewModel.loadSettings()
            if listViewModel.currentSettings.githubToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isSettingsPresented = true
            } else {
                await listViewModel.refreshRepositories(silentIfNoToken: true)
            }
        }
        .alert("안내", isPresented: Binding(
            get: { listViewModel.errorMessage != nil },
            set: { if !$0 { listViewModel.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { listViewModel.errorMessage = nil }
            if listViewModel.currentSettings.githubToken.isEmpty {
                Button("설정 열기") {
                    listViewModel.errorMessage = nil
                    isSettingsPresented = true
                }
            }
        } message: {
            Text(listViewModel.errorMessage ?? "")
        }
    }
}
