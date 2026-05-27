import SwiftUI

// MARK: - Card style modifiers

extension View {
    func animeCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(AnimeCardModifier(cornerRadius: cornerRadius, secondary: false))
    }

    func animeSecondaryCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(AnimeCardModifier(cornerRadius: cornerRadius, secondary: true))
    }

    // Tag chip — accent text on frosted material, neutral border
    func gradientTagStyle(fontSize: CGFloat = 11, paddingH: CGFloat = 7, paddingV: CGFloat = 2) -> some View {
        self
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
    }
}

struct AnimeCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let secondary: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 6, y: 2)
    }
}
