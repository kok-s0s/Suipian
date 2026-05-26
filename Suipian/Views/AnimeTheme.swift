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

    private var cardBackground: Color {
        if colorScheme == .dark {
            return secondary
                ? Color(red: 0.10, green: 0.13, blue: 0.20)
                : Color(red: 0.07, green: 0.09, blue: 0.16)
        } else {
            return secondary
                ? Color(red: 0.95, green: 0.96, blue: 0.98)
                : Color(red: 1.00, green: 1.00, blue: 1.00)
        }
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.accentColor.opacity(0.50)
            : Color.accentColor.opacity(0.20)
    }

    private var borderWidth: CGFloat {
        colorScheme == .dark ? 1.0 : 0.5
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .clear : Color.accentColor.opacity(0.10)
    }

    func body(content: Content) -> some View {
        content
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: shadowColor, radius: 8, y: 3)
    }
}
