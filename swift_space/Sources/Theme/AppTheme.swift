import SwiftUI

enum AppTheme {
    static let background = Color(red: 10/255, green: 14/255, blue: 26/255)
    static let accent = Color(red: 79/255, green: 195/255, blue: 247/255)
    static let cardBg = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.10)
    static let subtitleColor = Color.white.opacity(0.7)
    static let dimText = Color.white.opacity(0.4)

    static let win = Color.green
    static let loss = Color.red
    static let draw = Color.yellow
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
