import SwiftUI

/// Apple HIG 디자인 가이드라인 기반 테마 및 비주얼 토큰 (Apple Design Award 수준의 완성도)
public enum AppTheme {
    // MARK: - Vibrant Colors (macOS Pro Dark/Light System Tint)
    public static let activeGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
    public static let warningAmber = Color(red: 0.95, green: 0.61, blue: 0.07)
    public static let staleRose = Color(red: 0.94, green: 0.28, blue: 0.35)
    public static let subtleBlue = Color(red: 0.20, green: 0.55, blue: 0.95)
    public static let royalPurple = Color(red: 0.60, green: 0.35, blue: 0.95)

    // MARK: - Subtle Gradients
    public static let activeGradient = LinearGradient(
        colors: [Color(red: 0.18, green: 0.82, blue: 0.48), Color(red: 0.10, green: 0.65, blue: 0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let warningGradient = LinearGradient(
        colors: [Color(red: 0.98, green: 0.65, blue: 0.12), Color(red: 0.88, green: 0.48, blue: 0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let staleGradient = LinearGradient(
        colors: [Color(red: 0.96, green: 0.32, blue: 0.40), Color(red: 0.82, green: 0.18, blue: 0.28)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Springs & Micro-interactions
    public static let fluidSpring = Animation.spring(response: 0.32, dampingFraction: 0.82)
    public static let quickSpring = Animation.spring(response: 0.22, dampingFraction: 0.78)

    // MARK: - GitHub Language Colors
    public static func languageColor(for language: String?) -> Color {
        guard let lang = language?.lowercased() else {
            return Color.secondary
        }

        switch lang {
        case "swift":
            return Color(red: 0.98, green: 0.34, blue: 0.22) // Swift Orange
        case "typescript":
            return Color(red: 0.19, green: 0.47, blue: 0.78) // TS Blue
        case "javascript":
            return Color(red: 0.96, green: 0.85, blue: 0.21) // JS Yellow
        case "python":
            return Color(red: 0.21, green: 0.45, blue: 0.65) // Python Blue
        case "rust":
            return Color(red: 0.87, green: 0.38, blue: 0.25) // Rust Brown/Red
        case "go":
            return Color(red: 0.00, green: 0.68, blue: 0.84) // Go Cyan
        case "kotlin":
            return Color(red: 0.65, green: 0.30, blue: 0.95) // Kotlin Purple
        case "java":
            return Color(red: 0.70, green: 0.20, blue: 0.15) // Java Crimson
        case "c", "c++":
            return Color(red: 0.95, green: 0.28, blue: 0.47) // C++ Pink/Red
        case "c#":
            return Color(red: 0.10, green: 0.60, blue: 0.18) // C# Green
        case "ruby":
            return Color(red: 0.80, green: 0.15, blue: 0.18) // Ruby Dark Red
        case "html":
            return Color(red: 0.89, green: 0.30, blue: 0.16) // HTML Orange
        case "css":
            return Color(red: 0.34, green: 0.24, blue: 0.82) // CSS Indigo
        case "shell":
            return Color(red: 0.54, green: 0.76, blue: 0.29) // Shell Green
        case "dart":
            return Color(red: 0.00, green: 0.75, blue: 0.65) // Dart Teal
        default:
            return Color(red: 0.45, green: 0.50, blue: 0.55)
        }
    }

    // MARK: - Relative Date Formatter
    public static func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Glass Card Modifier (Apple Continuous Squircle + Dual Specular Stroke)
    public struct GlassCard: ViewModifier {
        var cornerRadius: CGFloat = 12
        var isHovered: Bool = false

        public func body(content: Content) -> some View {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.22 : 0.10),
                                    Color.white.opacity(isHovered ? 0.08 : 0.03),
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHovered ? 1.2 : 0.8
                        )
                )
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.12 : 0.04),
                    radius: isHovered ? 10 : 5,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
        }
    }
}

// MARK: - AIAgentPreset Brand Colors
extension AppSettings.AIAgentPreset {
    public var brandColor: Color {
        switch self {
        case .antigravity:
            return Color(red: 0.42, green: 0.58, blue: 1.00) // Antigravity Indigo
        case .claude:
            return Color(red: 0.96, green: 0.54, blue: 0.32) // Claude Terracotta
        case .codex:
            return Color(red: 0.20, green: 0.82, blue: 0.58) // OpenAI Mint
        case .cursor:
            return Color(red: 0.28, green: 0.68, blue: 0.98) // Cursor Cyan
        case .aider:
            return Color(red: 0.98, green: 0.74, blue: 0.20) // Aider Gold
        case .goose:
            return Color(red: 0.96, green: 0.38, blue: 0.55) // Goose Pink
        case .openhands:
            return Color(red: 0.22, green: 0.78, blue: 0.76) // OpenHands Teal
        case .custom:
            return Color.accentColor
        }
    }
}

extension View {
    public func glassCard(cornerRadius: CGFloat = 12, isHovered: Bool = false) -> some View {
        self.modifier(AppTheme.GlassCard(cornerRadius: cornerRadius, isHovered: isHovered))
    }
}
