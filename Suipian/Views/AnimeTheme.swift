import SwiftUI

enum AnimePalette {
    static let primary = Color(red: 0.48, green: 0.55, blue: 0.95)      // magic blue
    static let sakura = Color(red: 0.96, green: 0.50, blue: 0.68)       // sakura pink
    static let star = Color(red: 0.96, green: 0.72, blue: 0.34)         // star gold
    static let mint = Color(red: 0.38, green: 0.78, blue: 0.68)         // mint green
    static let violet = Color(red: 0.66, green: 0.54, blue: 0.98)       // dream violet
    static let coral = Color(red: 0.93, green: 0.36, blue: 0.40)

    static let lightBackground = Color(red: 0.975, green: 0.965, blue: 1.000)
    static let darkBackground = Color(red: 0.090, green: 0.085, blue: 0.155)

    static let softPrimary = primary.opacity(0.14)
    static let softSakura = sakura.opacity(0.14)
    static let softStar = star.opacity(0.16)
    static let softMint = mint.opacity(0.14)

    static let heroGradient = [primary, sakura]
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
            .foregroundStyle(.primary)
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
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
