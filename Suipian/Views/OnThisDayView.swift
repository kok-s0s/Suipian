import SwiftUI

struct OnThisDayView: View {
    let fragments: [Fragment]

    private var byYear: [(year: Int, fragments: [Fragment])] {
        let calendar = Calendar.current
        var grouped: [Int: [Fragment]] = [:]
        for f in fragments {
            let y = calendar.component(.year, from: f.date)
            grouped[y, default: []].append(f)
        }
        return grouped.keys.sorted(by: >).map { (year: $0, fragments: grouped[$0]!) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(byYear, id: \.year) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(section.year) 年")
                            .font(.title3).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)

                        ForEach(section.fragments) { fragment in
                            NavigationLink {
                                FragmentDetailView(fragment: fragment)
                            } label: {
                                FragmentCardView(fragment: fragment)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                            .padding(.horizontal, 16)
                            .scrollTransition(.animated(.spring(response: 0.5, dampingFraction: 0.88))) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : max(0, 1 - abs(phase.value) * 0.72))
                                    .scaleEffect(phase.isIdentity ? 1 : max(0.88, 1 - abs(phase.value) * 0.1))
                                    .rotation3DEffect(
                                        .degrees(phase.value * 12),
                                        axis: (x: 1, y: 0, z: 0),
                                        anchor: .center,
                                        perspective: 0.35
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
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
