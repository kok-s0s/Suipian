import SwiftUI

struct WrappedView: View {
    let fragments: [Fragment]
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private var cards: [WrappedCardData] { buildCards() }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $currentPage) {
                ForEach(cards.indices, id: \.self) { i in
                    WrappedCardView(card: cards[i])
                        .tag(i)
                        .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Top bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
                Spacer()
                // Page dots
                HStack(spacing: 5) {
                    ForEach(cards.indices, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(i == currentPage ? 0.9 : 0.35))
                            .frame(width: i == currentPage ? 16 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                Spacer()
                // Share on last card
                if currentPage == cards.count - 1 {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                } else {
                    // Placeholder to keep HStack balanced
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundStyle(.clear)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
        .statusBarHidden()
    }

    private var shareText: String {
        var lines: [String] = ["✨ 我的碎片回顾"]
        lines.append("共记录了 \(fragments.count) 条碎片")
        if let top = topMonthInfo() {
            lines.append("最活跃的月份：\(top.label)，\(top.count) 条")
        }
        if let mood = topMoodInfo() {
            lines.append("最常用的情绪：\(mood.emoji)，共 \(mood.count) 次")
        }
        if let tag = topTagInfo() {
            lines.append("最常用的标签：#\(tag.tag)，\(tag.count) 条")
        }
        lines.append("— 来自碎片 App")
        return lines.joined(separator: "\n")
    }

    // MARK: - Card builders

    private func buildCards() -> [WrappedCardData] {
        var result: [WrappedCardData] = []

        // Gradients use muted, warm-toned pairs — vivid system colors (.purple/.teal/.cyan)
        // replaced with desaturated equivalents that suit the cream/ink palette.
        result.append(WrappedCardData(
            gradient: [Color(red: 0.40, green: 0.28, blue: 0.52), Color(red: 0.26, green: 0.17, blue: 0.38)],
            icon: "sparkles", highlight: "✨",
            title: "你的碎片回忆", subtitle: "滑动，开始回顾"
        ))

        result.append(WrappedCardData(
            gradient: [Color(red: 0.22, green: 0.34, blue: 0.56), Color(red: 0.16, green: 0.26, blue: 0.46)],
            icon: "square.on.square.fill", highlight: "\(fragments.count)",
            title: "条碎片", subtitle: "每一条都是你珍贵的记忆"
        ))

        if let top = topMonthInfo() {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.20, green: 0.42, blue: 0.34), Color(red: 0.14, green: 0.32, blue: 0.26)],
                icon: "calendar", highlight: top.label,
                title: "月最为活跃", subtitle: "共留下了 \(top.count) 条碎片"
            ))
        }

        if let mood = topMoodInfo() {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.62, green: 0.38, blue: 0.14), Color(red: 0.48, green: 0.28, blue: 0.10)],
                icon: "heart.fill", highlight: mood.emoji,
                title: "是你最常用的情绪", subtitle: "共出现了 \(mood.count) 次"
            ))
        }

        if let tag = topTagInfo() {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.50, green: 0.20, blue: 0.34), Color(red: 0.38, green: 0.14, blue: 0.26)],
                icon: "tag.fill", highlight: "#\(tag.tag)",
                title: "是你最常用的标签", subtitle: "关联了 \(tag.count) 条碎片"
            ))
        }

        if let loc = topLocationInfo() {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.18, green: 0.38, blue: 0.48), Color(red: 0.12, green: 0.28, blue: 0.38)],
                icon: "location.fill", highlight: loc.name,
                title: "是你最常出现的地方", subtitle: "共记录了 \(loc.count) 次"
            ))
        }

        if let longest = longestFragmentInfo() {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.24, green: 0.42, blue: 0.28), Color(red: 0.16, green: 0.30, blue: 0.20)],
                icon: "text.alignleft", highlight: "\(longest.charCount) 字",
                title: "是你写过最长的一段话", subtitle: longest.preview
            ))
        }

        if let period = topTimePeriodInfo() {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.44, green: 0.32, blue: 0.16), Color(red: 0.32, green: 0.22, blue: 0.10)],
                icon: period.icon, highlight: period.label,
                title: "是你最爱记录的时段", subtitle: "共 \(period.count) 条碎片在这个时段"
            ))
        }

        result.append(WrappedCardData(
            gradient: [Color(red: 0.34, green: 0.20, blue: 0.44), Color(red: 0.46, green: 0.24, blue: 0.40)],
            icon: "star.fill", highlight: "🌟",
            title: "继续记录吧", subtitle: "每一个碎片，都是你独特的印记"
        ))

        return result
    }

    private func topLocationInfo() -> (name: String, count: Int)? {
        var counts: [String: Int] = [:]
        for f in fragments where !f.locationName.isEmpty {
            counts[f.locationName, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }), top.value >= 2 else { return nil }
        let name = top.key.count > 8 ? String(top.key.prefix(8)) + "…" : top.key
        return (name: name, count: top.value)
    }

    private func longestFragmentInfo() -> (charCount: Int, preview: String)? {
        guard let f = fragments.max(by: { $0.content.count < $1.content.count }),
              f.content.count > 50 else { return nil }
        let preview = String(f.content.prefix(30)).replacingOccurrences(of: "\n", with: " ") + "…"
        return (charCount: f.content.count, preview: preview)
    }

    private func topTimePeriodInfo() -> (label: String, icon: String, count: Int)? {
        var morning = 0, afternoon = 0, evening = 0, night = 0
        let cal = Calendar.current
        for f in fragments {
            let hour = cal.component(.hour, from: f.date)
            switch hour {
            case 6..<12:  morning += 1
            case 12..<18: afternoon += 1
            case 18..<24: evening += 1
            default:      night += 1
            }
        }
        let periods = [
            ("早晨", "sunrise.fill", morning),
            ("午后", "sun.max.fill", afternoon),
            ("傍晚", "sunset.fill", evening),
            ("深夜", "moon.stars.fill", night)
        ]
        guard let top = periods.max(by: { $0.2 < $1.2 }), top.2 > 0 else { return nil }
        return (label: top.0, icon: top.1, count: top.2)
    }

    private func topMonthInfo() -> (label: String, count: Int)? {
        let cal = Calendar.current
        var counts: [String: Int] = [:]
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "M"
        for f in fragments {
            let key = fmt.string(from: f.date)
            counts[key, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }),
              let date = fmt.date(from: top.key) else { return nil }
        _ = cal
        return (label: displayFmt.string(from: date), count: top.value)
    }

    private func topMoodInfo() -> (emoji: String, count: Int)? {
        var counts: [String: Int] = [:]
        for f in fragments where !f.mood.isEmpty { counts[f.mood, default: 0] += 1 }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (emoji: top.key, count: top.value)
    }

    private func topTagInfo() -> (tag: String, count: Int)? {
        var counts: [String: Int] = [:]
        for f in fragments { for t in f.tags { counts[t, default: 0] += 1 } }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (tag: top.key, count: top.value)
    }

}

// MARK: - Card data

private struct WrappedCardData {
    let gradient: [Color]
    let icon: String
    let highlight: String
    let title: String
    let subtitle: String
}

// MARK: - Card view

private struct WrappedCardView: View {
    let card: WrappedCardData
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(colors: card.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Subtle texture dots
            GeometryReader { geo in
                ForEach(0..<18, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(0.04))
                        .frame(width: CGFloat.random(in: 40...120))
                        .position(
                            x: CGFloat(i * 47 % Int(geo.size.width)),
                            y: CGFloat(i * 83 % Int(geo.size.height))
                        )
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: card.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .white.opacity(0.3), radius: 12)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.05), value: appeared)

                Text(card.highlight)
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .offset(y: appeared ? 0 : 28)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.72).delay(0.15), value: appeared)

                Text(card.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.45).delay(0.28), value: appeared)

                Text(card.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.45).delay(0.38), value: appeared)

                Spacer()
                Spacer()
            }
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}
