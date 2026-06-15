import SwiftUI

// Canvas-based confetti — no external dependencies.
// Usage: ConfettiView(isVisible: $showConfetti)
struct ConfettiView: View {
    @Binding var isVisible: Bool

    private struct Particle {
        let id: Int
        let x0, y0, vx, vy: CGFloat
        let rotStart, rotSpeed: Double
        let size: CGFloat
        let color: Color
        let delay: Double
    }

    @State private var particles: [Particle] = []
    @State private var launchTime: Date = .distantPast

    private static let palette: [Color] = [
        AnimePalette.primary,
        AnimePalette.star,
        Color(red: 0.28, green: 0.65, blue: 0.42),
        Color(red: 0.88, green: 0.35, blue: 0.25),
        Color(red: 0.68, green: 0.32, blue: 0.72),
        Color(red: 0.95, green: 0.76, blue: 0.18),
    ]

    var body: some View {
        if isVisible {
            TimelineView(.animation(minimumInterval: 1/60, paused: particles.isEmpty)) { tl in
                Canvas { ctx, size in
                    let elapsed = tl.date.timeIntervalSince(launchTime)
                    if particles.isEmpty {
                        DispatchQueue.main.async { launch(width: size.width) }
                    }
                    for p in particles {
                        let t = max(0, elapsed - p.delay)
                        guard t < 2.8 else { continue }
                        let x = p.x0 + p.vx * t
                        let y = p.y0 + p.vy * t + 180 * t * t
                        let angle = (p.rotStart + p.rotSpeed * t) * .pi / 180
                        let opacity = t < 2.0 ? 1.0 : max(0, 1 - (t - 2.0) / 0.8)

                        ctx.drawLayer { lc in
                            lc.opacity = opacity
                            lc.translateBy(x: x, y: y)
                            lc.rotate(by: .radians(angle))
                            lc.fill(
                                Path(CGRect(x: -p.size / 2, y: -p.size / 4,
                                           width: p.size, height: p.size / 2)),
                                with: .color(p.color)
                            )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .onAppear { launch(width: 390) }
        }
    }

    private func launch(width: CGFloat) {
        launchTime = Date()
        let w = max(width, 1)
        particles = (0..<90).map { i in
            Particle(
                id: i,
                x0: CGFloat.random(in: 0...w),
                y0: CGFloat.random(in: -200 ... -10),
                vx: CGFloat.random(in: -100...100),
                vy: CGFloat.random(in: 10...140),
                rotStart: Double.random(in: 0...360),
                rotSpeed: Double.random(in: -200...200),
                size: CGFloat.random(in: 6...14),
                color: Self.palette.randomElement()!,
                delay: Double.random(in: 0...0.45)
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            isVisible = false
            particles = []
        }
    }
}
