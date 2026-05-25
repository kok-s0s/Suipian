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
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(todayTitle())
        .navigationBarTitleDisplayMode(.large)
    }

    private func todayTitle() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M 月 d 日"
        return fmt.string(from: Date())
    }
}
