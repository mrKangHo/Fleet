import SwiftUI

/// 음성 명령 전체화면 오버레이 — 앱 창 전체를 덮는 HUD 스타일 음성 인터페이스
public struct VoiceAssistantOverlayView: View {
    @ObservedObject var viewModel: VoiceAssistantViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    public init(viewModel: VoiceAssistantViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture { viewModel.dismissOverlay() }

            VStack(spacing: 28) {
                Spacer()

                Text("FLEET")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundColor(.accentColor.opacity(0.8))

                micButton

                Text(statusLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.transcript.isEmpty {
                        exchangeRow(label: "나", text: viewModel.transcript, color: .secondary)
                    }
                    if !viewModel.responseText.isEmpty {
                        exchangeRow(label: "Fleet", text: viewModel.responseText, color: .accentColor)
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .opacity(viewModel.transcript.isEmpty && viewModel.responseText.isEmpty ? 0 : 1)
                .frame(minHeight: 90)

                if case .error(let message) = viewModel.state {
                    Text(message)
                        .font(.callout)
                        .foregroundColor(AppTheme.staleRose)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)
                }

                Spacer()

                VStack(spacing: 10) {
                    Text("\"브리핑해줘\" · \"OO 저장소 열어줘\" 같은 명령이나, 그냥 편하게 말을 걸어도 돼요")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Button("닫기 (Esc)") { viewModel.dismissOverlay() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand { viewModel.dismissOverlay() }
        .onChange(of: viewModel.state) { _, newValue in
            isPulsing = (newValue == .listening)
        }
    }

    private func exchangeRow(label: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 17))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var micButton: some View {
        Button(action: { viewModel.toggleListening() }) {
            ZStack {
                Circle()
                    .stroke(micColor.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 168, height: 168)
                    .scaleEffect(isPulsing && !reduceMotion ? 1.18 : 1.0)
                    .opacity(isPulsing && !reduceMotion ? 0 : 1)
                    .animation(
                        isPulsing && !reduceMotion
                            ? .easeOut(duration: 1.4).repeatForever(autoreverses: false)
                            : .default,
                        value: isPulsing
                    )

                Circle()
                    .fill(micColor.opacity(0.12))
                    .frame(width: 132, height: 132)
                    .scaleEffect(isPulsing && !reduceMotion ? 1.1 : 1.0)
                    .animation(
                        isPulsing && !reduceMotion
                            ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                            : .default,
                        value: isPulsing
                    )

                Circle()
                    .fill(micColor.opacity(0.22))
                    .frame(width: 100, height: 100)

                Image(systemName: micIconName)
                    .font(.system(size: 36))
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
