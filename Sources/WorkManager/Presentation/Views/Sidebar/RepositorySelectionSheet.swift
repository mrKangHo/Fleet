import SwiftUI

/// 관리할 저장소를 선택하거나 수정하는 모달 시트
public struct RepositorySelectionSheet: View {
    @ObservedObject var viewModel: RepositoryListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: Set<Int> = []
    @State private var searchText: String = ""

    public init(viewModel: RepositoryListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 상단 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                        Text("관리할 저장소 선택 및 수정")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                    }
                    Text("업데이트 주기 추적과 메모, AI 작업을 진행할 저장소를 체크해 주세요. 체크 해제된 저장소는 목록과 알림에서 제외됩니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("닫기") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

            // MARK: - 검색 및 퀵 액션 바
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("저장소 검색...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // 퀵 토글 캡슐 버튼
                HStack(spacing: 6) {
                    quickButton(title: "모두 선택") {
                        selectedIds = Set(viewModel.allFetchedRepositories.map { $0.id })
                    }
                    quickButton(title: "모두 해제") {
                        selectedIds.removeAll()
                    }
                    quickButton(title: "비공개(Private)만") {
                        selectedIds = Set(viewModel.allFetchedRepositories.filter { $0.isPrivate }.map { $0.id })
                    }
                    quickButton(title: "방치(30일 이상)만") {
                        selectedIds = Set(viewModel.allFetchedRepositories.filter {
                            viewModel.staleStatus(for: $0).isStale
                        }.map { $0.id })
                    }

                    Spacer()

                    Text("\(selectedIds.count) / \(viewModel.allFetchedRepositories.count)개 선택됨")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))

            Divider()

            // MARK: - 저장소 목록 테이블/리스트
            let displayList = filteredAllRepos
            if displayList.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("표시할 저장소가 없습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(displayList) { repo in
                        let isChecked = selectedIds.contains(repo.id)
                        let status = viewModel.staleStatus(for: repo)

                        HStack(spacing: 12) {
                            // 체크박스
                            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                .font(.system(size: 16))
                                .foregroundColor(isChecked ? .accentColor : .secondary)

                            // 저장소 정보
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(repo.name)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)

                                    if repo.isPrivate {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // D-Day 뱃지
                                    Text(status.displayBadge)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.12))
                                        .cornerRadius(4)
                                }

                                HStack(spacing: 8) {
                                    if let lang = repo.language {
                                        HStack(spacing: 3) {
                                            Circle().fill(AppTheme.languageColor(for: lang)).frame(width: 6, height: 6)
                                            Text(lang).font(.caption2).foregroundColor(.secondary)
                                        }
                                    }

                                    if let date = repo.latestActivityDate {
                                        Text("마지막 커밋: \(formatDate(date))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    if let desc = repo.description, !desc.isEmpty {
                                        Text("• \(desc)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedIds.contains(repo.id) {
                                selectedIds.remove(repo.id)
                            } else {
                                selectedIds.insert(repo.id)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // MARK: - 하단 확정 버튼
            HStack {
                Text("선택한 저장소들만 앱의 사이드바와 독(Dock) 뱃지, 알림 대상에 포함됩니다.")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button("선택한 \(selectedIds.count)개 저장소 관리 시작") {
                    viewModel.saveSelectedRepositories(selectedIds: selectedIds)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .frame(width: 620, height: 540)
        .onAppear {
            // 기존 선택 상태 로드
            if let monitored = viewModel.currentSettings.monitoredRepoIds {
                self.selectedIds = monitored
            } else {
                // 첫 진입 시: 제외 목록에 없는 전체 저장소를 기본 선택
                let all = Set(viewModel.allFetchedRepositories.map { $0.id })
                self.selectedIds = all.subtracting(viewModel.currentSettings.ignoredRepoIds)
            }
        }
    }

    private var filteredAllRepos: [RepositoryItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.allFetchedRepositories
        }
        let q = searchText.lowercased()
        return viewModel.allFetchedRepositories.filter {
            $0.name.lowercased().contains(q) ||
            ($0.description?.lowercased().contains(q) ?? false) ||
            ($0.language?.lowercased().contains(q) ?? false)
        }
    }

    private func quickButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.mini)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
