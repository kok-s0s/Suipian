import SwiftUI

// MARK: - Icon design (1024×1024 reference)

struct AppIconView: View {
    var size: CGFloat = 1024

    private var unit: CGFloat { size / 1024 }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.13, blue: 0.20),
                    Color(red: 0.08, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Back square
            RoundedRectangle(cornerRadius: 100 * unit)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.40, green: 0.45, blue: 0.90).opacity(0.6),
                            Color(red: 0.25, green: 0.30, blue: 0.75).opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 480 * unit, height: 480 * unit)
                .rotationEffect(.degrees(12))
                .offset(x: 60 * unit, y: 60 * unit)
                .blur(radius: 2 * unit)

            // Front square
            RoundedRectangle(cornerRadius: 100 * unit)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.62, blue: 1.00),
                            Color(red: 0.38, green: 0.45, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 480 * unit, height: 480 * unit)
                .rotationEffect(.degrees(-6))
                .offset(x: -40 * unit, y: -40 * unit)
                .shadow(color: .black.opacity(0.3), radius: 30 * unit, y: 10 * unit)

            // Chinese character
            Text("碎")
                .font(.system(size: 260 * unit, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.6).opacity(0.5),
                        radius: 8 * unit, y: 4 * unit)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237)) // iOS icon corner ratio
    }
}

// MARK: - Export helper (Debug only, accessible from Settings)

@MainActor
func exportAppIcon() async {
    let view = AppIconView(size: 1024)
        .ignoresSafeArea()
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    renderer.proposedSize = .init(width: 1024, height: 1024)
    guard let img = renderer.uiImage else { return }
    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
}
