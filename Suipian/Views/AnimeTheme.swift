import SwiftUI

// MARK: - Card style modifiers

extension View {
    func animeCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(AnimeCardModifier(cornerRadius: cornerRadius, secondary: false))
    }

    func animeSecondaryCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(AnimeCardModifier(cornerRadius: cornerRadius, secondary: true))
    }

    // Frosted glass disc for toolbar icon buttons — matches FAB material
    func glassToolbarIcon(active: Bool = false) -> some View {
        self
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(active ? Color.accentColor : .secondary)
            .frame(width: 34, height: 34)
            .background(Circle().fill(.ultraThinMaterial))
    }

    // Tag chip — secondary text, subtle material pill; accent is reserved for
    // primary actions only so the feed doesn't drown in blue
    func gradientTagStyle(fontSize: CGFloat = 11, paddingH: CGFloat = 7, paddingV: CGFloat = 2) -> some View {
        self
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
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
