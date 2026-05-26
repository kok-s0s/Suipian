import SwiftUI

// MARK: - Card style modifiers

extension View {
    func animeCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(AnimeCardModifier(cornerRadius: cornerRadius, secondary: false))
    }

    func animeSecondaryCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(AnimeCardModifier(cornerRadius: cornerRadius, secondary: true))
    }
}

struct AnimeCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let secondary: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.accentColor.opacity(secondary ? 0.35 : 0.45)
            : Color.accentColor.opacity(secondary ? 0.14 : 0.20)
    }

    private var borderWidth: CGFloat {
        colorScheme == .dark ? 1.0 : 0.5
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .clear : Color.accentColor.opacity(0.10)
    }

    // Tint overlay for secondary cards to visually separate from primary
    private var tintOverlay: Color {
        secondary
            ? Color.accentColor.opacity(colorScheme == .dark ? 0.04 : 0.03)
            : .clear
    }

    func body(content: Content) -> some View {
        content
            // ② Glassmorphism: ultraThinMaterial lets the gradient background show through
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(tintOverlay, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: shadowColor, radius: 8, y: 3)
    }
}
