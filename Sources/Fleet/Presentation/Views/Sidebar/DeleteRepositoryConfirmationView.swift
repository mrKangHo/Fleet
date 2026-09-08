import SwiftUI

/// GitHub 저장소 영구 삭제 확인 시트 (저장소 전체 이름을 정확히 입력해야 삭제 가능)
public struct DeleteRepositoryConfirmationView: View {
    @ObservedObject var viewModel: RepositoryListViewModel
    public let repository: RepositoryItem
    @Environment(\.dismiss) private var dismiss

    @State private var typedName: String = ""

    public init(viewModel: RepositoryListViewModel, repository: RepositoryItem) {
        self.viewModel = viewModel
        self.repository = repository
    }

    private var isConfirmed: Bool {
        typedName == repository.fullName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.staleRose)
                Text("저장소 삭제")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                Spacer()
            }

            Text("이 작업은 되돌릴 수 없습니다. **\(repository.fullName)** 저장소와 모든 커밋, 이슈, 코멘트가 GitHub에서 영구적으로 삭제됩니다.")
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("계속하려면 저장소 전체 이름(\(repository.fullName))을 입력하세요.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField(repository.fullName, text: $typedName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("취소") {
                    viewModel.repositoryPendingDeletion = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    Task {
                        let success = await viewModel.confirmDeleteRepository(repository)
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isMutatingRepository {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("영구 삭제")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.staleRose)
                .disabled(!isConfirmed || viewModel.isMutatingRepository)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
