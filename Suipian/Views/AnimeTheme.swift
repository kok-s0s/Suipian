import SwiftUI

enum AnimePalette {
    static let primary = Color(red: 0.24, green: 0.64, blue: 0.98)      // electric blue
    static let sakura = Color(red: 0.96, green: 0.33, blue: 0.40)       // neon crimson
    static let star = Color(red: 0.98, green: 0.76, blue: 0.18)         // signal amber
    static let mint = Color(red: 0.20, green: 0.82, blue: 0.76)          // neon teal
    static let violet = Color(red: 0.56, green: 0.42, blue: 0.98)       // arc violet
    static let coral = Color(red: 0.95, green: 0.48, blue: 0.24)

    static let lightBackground = Color(red: 0.955, green: 0.965, blue: 0.985)
    static let darkBackground = Color(red: 0.045, green: 0.055, blue: 0.105)

    static let softPrimary = primary.opacity(0.18)
    static let softSakura = sakura.opacity(0.16)
    static let softStar = star.opacity(0.18)
    static let softMint = mint.opacity(0.16)

    static let heroGradient = [primary, violet]
    static let warmGradient = [sakura, star]
    static let coolGradient = [primary, mint]
}

// MARK: - Card style modifiers

extension View {
    func animeCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(AnimeCardModifier(cornerRadius: cornerRadius, secondary: false))
    }

    func animeSecondaryCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(AnimeCardModifier(cornerRadius: cornerRadius, secondary: true))
    }

    // Frosted glass disc for toolbar icon buttons — matches FAB material
    func glassToolbarIcon(size: CGFloat = 34, active: Bool = false) -> some View {
        self
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(active ? AnimePalette.primary : .secondary)
            .frame(width: size, height: size)
            .background(Circle().fill(.ultraThinMaterial))
    }

    // Tag chip — secondary text, subtle material pill; accent is reserved for
    // primary actions only so the feed doesn't drown in blue
    func gradientTagStyle(fontSize: CGFloat = 11, paddingH: CGFloat = 7, paddingV: CGFloat = 2) -> some View {
        self
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(AnimePalette.primary.opacity(0.22), lineWidth: 0.6))
    }
}

// Press-to-scale button style — provides tactile depth on card taps
struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct AnimeCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let secondary: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: secondary
                        ? [Color.white.opacity(0.12), Color.black.opacity(0.02)]
                        : [AnimePalette.primary.opacity(0.08), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        (secondary ? AnimePalette.mint : AnimePalette.primary).opacity(colorScheme == .dark ? 0.28 : 0.18),
                        lineWidth: secondary ? 0.8 : 0.7
                    )
            )
            .shadow(color: (secondary ? AnimePalette.violet : AnimePalette.primary).opacity(colorScheme == .dark ? 0.14 : 0.08), radius: 10, y: 3)
    }
}
