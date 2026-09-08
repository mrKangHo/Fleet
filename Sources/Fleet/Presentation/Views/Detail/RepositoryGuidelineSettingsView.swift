import SwiftUI

/// 저장소 × AI 에이전트별 지침 파일(CLAUDE.md, AGENTS.md 등)을 편집하는 시트
public struct RepositoryGuidelineSettingsView: View {
    @ObservedObject var viewModel: RepositoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: RepositoryDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 0) {
            // 좌측: AI 에이전트 프리셋 목록
            VStack(alignment: .leading, spacing: 0) {
                Text("AI 에이전트")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(AppSettings.AIAgentPreset.allCases) { preset in
                            presetRow(preset)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .frame(width: 210)
            .background(AppTheme.stitchContainerLowest)

            Divider()

            // 우측: 선택된 프리셋의 지침 편집 영역
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: viewModel.guidelineSelectedPreset.iconName)
                        .foregroundColor(.accentColor)
                    Text("\(viewModel.guidelineSelectedPreset.shortName) 지침")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                    Spacer()
                    Button("닫기") { dismiss() }
                }

                if let path = viewModel.guidelineFilePath(for: viewModel.guidelineSelectedPreset) {
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                TextEditor(text: $viewModel.guidelineContent)
                    .font(.system(size: 13, design: .monospaced))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack {
                    Spacer()
                    Button("저장") {
                        viewModel.saveGuideline()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 480)
    }

    @ViewBuilder
    private func presetRow(_ preset: AppSettings.AIAgentPreset) -> some View {
        let isSelected = viewModel.guidelineSelectedPreset == preset
        Button {
            viewModel.selectGuidelinePreset(preset)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: preset.iconName)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.shortName)
                        .font(.system(size: 12, weight: .semibold))
                    Text(preset.guidelineFileName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if viewModel.guidelineExists(for: preset) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.activeGreen)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
