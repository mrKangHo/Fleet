import SwiftUI

/// GitHub에 새 저장소를 생성하는 시트
public struct CreateRepositorySheetView: View {
    @ObservedObject var viewModel: RepositoryListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isPrivate: Bool = true
    @State private var validationMessage: String?

    public init(viewModel: RepositoryListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "plus.app.fill")
                    .foregroundColor(.accentColor)
                Text("새 저장소 생성")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("저장소 이름")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("my-new-repo", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: name) { validationMessage = nil }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("설명 (선택)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("저장소에 대한 짧은 설명", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Private 저장소로 생성", isOn: $isPrivate)
                .toggleStyle(.switch)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    Task {
                        guard validate() else { return }
                        let success = await viewModel.createRepository(
                            name: name.trimmingCharacters(in: .whitespaces),
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            isPrivate: isPrivate
                        )
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isMutatingRepository {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("생성")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isMutatingRepository || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func validate() -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard !trimmed.isEmpty else {
            validationMessage = "저장소 이름을 입력해 주세요."
            return false
        }
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            validationMessage = "영문, 숫자, '-', '_', '.'만 사용할 수 있습니다."
            return false
        }
        validationMessage = nil
        return true
    }
}
