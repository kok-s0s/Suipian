import SwiftUI

struct OnThisDayView: View {
    let fragments: [Fragment]

    private var byYear: [(year: Int, fragments: [Fragment])] {
        let cal = Calendar.current
        var grouped: [Int: [Fragment]] = [:]
        for f in fragments {
            let y = cal.component(.year, from: f.date)
            grouped[y, default: []].append(f)
        }
        return grouped.keys.sorted(by: >).map { (year: $0, fragments: grouped[$0]!) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(byYear.enumerated()), id: \.element.year) { idx, section in
                    TimelineSection(
                        year: section.year,
                        fragments: section.fragments,
                        isLast: idx == byYear.count - 1
                    )
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background { AppBackgroundCanvas().ignoresSafeArea() }
        .navigationTitle(todayTitle())
        .navigationBarTitleDisplayMode(.large)
    }

    private func todayTitle() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M 月 d 日"
        return fmt.string(from: Date())
    }
}

// MARK: - Timeline section

private struct TimelineSection: View {
    let year: Int
    let fragments: [Fragment]
    let isLast: Bool

    private let lineX: CGFloat = 44
    private let dotSize: CGFloat = 10

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: year label + vertical line
            ZStack(alignment: .top) {
                if !isLast {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1.5)
                        .padding(.top, dotSize + 4)
                        .frame(maxHeight: .infinity)
                }
                VStack(spacing: 4) {
                    Circle()
                        .fill(AnimePalette.primary)
                        .frame(width: dotSize, height: dotSize)
                        .shadow(color: AnimePalette.primary.opacity(0.4), radius: 4)
                    Text(String(year))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AnimePalette.primary)
                        .monospacedDigit()
                }
            }
            .frame(width: lineX)

            // Right: cards
            VStack(alignment: .leading, spacing: 12) {
                ForEach(fragments) { fragment in
                    NavigationLink {
                        FragmentDetailView(fragment: fragment)
                    } label: {
                        FragmentCardView(fragment: fragment)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .scrollTransition(.animated(.spring(response: 0.5, dampingFraction: 0.88))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : max(0, 1 - abs(phase.value) * 0.72))
                            .scaleEffect(phase.isIdentity ? 1 : max(0.88, 1 - abs(phase.value) * 0.1))
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.bottom, isLast ? 0 : 28)
        }
        .padding(.leading, 16)
    }
}
