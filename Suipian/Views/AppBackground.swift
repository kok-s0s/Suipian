import SwiftUI

// ⑤ Background texture drawn with Canvas

struct AppBackgroundCanvas: View {
    @AppStorage("backgroundStyle") private var styleRaw = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let opacity: Double = colorScheme == .dark ? 0.09 : 0.06
        switch styleRaw {
        case 1:
            Canvas { ctx, size in dotPattern(ctx: ctx, size: size) }
                .foregroundStyle(Color.accentColor)
                .opacity(opacity)
                .allowsHitTesting(false)
        case 2:
            Canvas { ctx, size in diagonalPattern(ctx: ctx, size: size) }
                .foregroundStyle(Color.accentColor)
                .opacity(opacity)
                .allowsHitTesting(false)
        case 3:
            Canvas { ctx, size in gridPattern(ctx: ctx, size: size) }
                .foregroundStyle(Color.accentColor)
                .opacity(opacity)
                .allowsHitTesting(false)
        default:
            Color.clear.allowsHitTesting(false)
        }
    }

    private func dotPattern(ctx: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 22
        for x in stride(from: spacing / 2, to: size.width + spacing, by: spacing) {
            for y in stride(from: spacing / 2, to: size.height + spacing, by: spacing) {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)),
                    with: .foreground
                )
            }
        }
    }

    private func diagonalPattern(ctx: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 18
        var path = Path()
        let count = Int((size.width + size.height) / spacing) + 4
        for i in 0..<count {
            let x = CGFloat(i) * spacing - size.height
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x + size.height, y: size.height))
        }
        ctx.stroke(path, with: .foreground, lineWidth: 0.6)
    }

    private func gridPattern(ctx: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 26
        var path = Path()
        for x in stride(from: 0, through: size.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: 0, through: size.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(path, with: .foreground, lineWidth: 0.4)
    }
}
