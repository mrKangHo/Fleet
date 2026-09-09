import SwiftUI

/// 음성 명령 오버레이 — 상태(대기/듣는 중/생각 중/응답 중)와 실시간 트랜스크립트/응답을 보여준다
public struct VoiceAssistantOverlayView: View {
    @ObservedObject var viewModel: VoiceAssistantViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    public init(viewModel: VoiceAssistantViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Jarvis")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                Spacer()
                Button("닫기") {
                    viewModel.dismissOverlay()
                    dismiss()
                }
            }

            micButton

            Text(statusLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                if !viewModel.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("나")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(viewModel.transcript)
                            .font(.system(size: 14))
                    }
                }

                if !viewModel.responseText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Jarvis")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentColor)
                        Text(viewModel.responseText)
                            .font(.system(size: 14))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.stitchContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(minHeight: 80)

            if case .error(let message) = viewModel.state {
                Text(message)
                    .font(.caption)
                    .foregroundColor(AppTheme.staleRose)
            }

            Text("\"브리핑해줘\", \"OO 저장소 열어줘\", \"상태 알려줘\", \"메모 현황 알려줘\"")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 380)
        .onChange(of: viewModel.state) { _, newValue in
            isPulsing = (newValue == .listening)
        }
    }

    private var micButton: some View {
        Button(action: { viewModel.toggleListening() }) {
            ZStack {
                Circle()
                    .fill(micColor.opacity(0.15))
                    .frame(width: 84, height: 84)
                    .scaleEffect(isPulsing && !reduceMotion ? 1.15 : 1.0)
                    .animation(
                        isPulsing && !reduceMotion
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: isPulsing
                    )

                Circle()
                    .fill(micColor.opacity(0.25))
                    .frame(width: 64, height: 64)

                Image(systemName: micIconName)
                    .font(.system(size: 26))
                    .foregroundColor(micColor)
            }
        }
        .buttonStyle(.plain)
    }

    private var micIconName: String {
        switch viewModel.state {
        case .listening: return "mic.fill"
        case .thinking: return "ellipsis"
        case .speaking: return "waveform"
        case .error: return "exclamationmark.triangle.fill"
        case .idle: return "mic"
        }
    }

    private var micColor: Color {
        switch viewModel.state {
        case .listening: return AppTheme.activeGreen
        case .thinking: return .accentColor
        case .speaking: return .accentColor
        case .error: return AppTheme.staleRose
        case .idle: return .secondary
        }
    }

    private var statusLabel: String {
        switch viewModel.state {
        case .idle: return "탭해서 말하기"
        case .listening: return "듣고 있어요..."
        case .thinking: return "생각 중..."
        case .speaking: return "응답 중"
        case .error: return "오류"
        }
    }
}
