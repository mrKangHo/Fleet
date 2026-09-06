import SwiftUI

/// Apple HIG 디자인 가이드라인 기반 테마 및 비주얼 토큰
public enum AppTheme {
    // MARK: - Vibrant Colors
    public static let activeGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
    public static let warningAmber = Color(red: 0.95, green: 0.61, blue: 0.07)
    public static let staleRose = Color(red: 0.94, green: 0.28, blue: 0.35)

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

    // MARK: - Glass Card Modifier
    public struct GlassCard: ViewModifier {
        var cornerRadius: CGFloat = 12
        var isHovered: Bool = false

        public func body(content: Content) -> some View {
            content
                .background(.ultraThinMaterial)
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            isHovered
                                ? Color.accentColor.opacity(0.4)
                                : Color.primary.opacity(0.08),
                            lineWidth: isHovered ? 1.5 : 1
                        )
                )
                .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 8 : 4, y: 2)
        }
    }
}

extension View {
    public func glassCard(cornerRadius: CGFloat = 12, isHovered: Bool = false) -> some View {
        self.modifier(AppTheme.GlassCard(cornerRadius: cornerRadius, isHovered: isHovered))
    }
}
