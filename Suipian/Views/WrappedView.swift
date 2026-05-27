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

        result.append(WrappedCardData(
            gradient: [.purple.opacity(0.85), Color(red: 0.3, green: 0.1, blue: 0.55)],
            icon: "sparkles", highlight: "✨",
            title: "你的碎片回忆", subtitle: "滑动，开始回顾"
        ))

        result.append(WrappedCardData(
            gradient: [Color(red: 0.15, green: 0.35, blue: 0.75), .cyan.opacity(0.7)],
            icon: "square.on.square.fill", highlight: "\(fragments.count)",
            title: "条碎片", subtitle: "每一条都是你珍贵的记忆"
        ))

        if let top = topMonthInfo() {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.1, green: 0.5, blue: 0.35), .teal.opacity(0.75)],
                icon: "calendar", highlight: top.label,
                title: "月最为活跃", subtitle: "共留下了 \(top.count) 条碎片"
            ))
        }

        if let mood = topMoodInfo() {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.7, green: 0.4, blue: 0.1), .yellow.opacity(0.65)],
                icon: "heart.fill", highlight: mood.emoji,
                title: "是你最常用的情绪", subtitle: "共出现了 \(mood.count) 次"
            ))
        }

        if let tag = topTagInfo() {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.55, green: 0.1, blue: 0.35), .pink.opacity(0.7)],
                icon: "tag.fill", highlight: "#\(tag.tag)",
                title: "是你最常用的标签", subtitle: "关联了 \(tag.count) 条碎片"
            ))
        }

        let streak = computeStreak()
        if streak > 1 {
            result.append(WrappedCardData(
                gradient: [Color(red: 0.65, green: 0.2, blue: 0.05), .orange.opacity(0.75)],
                icon: "flame.fill", highlight: "\(streak)",
                title: "天连续记录", subtitle: "你的坚持，值得被铭记"
            ))
        }

        result.append(WrappedCardData(
            gradient: [Color(red: 0.4, green: 0.15, blue: 0.6), Color(red: 0.6, green: 0.25, blue: 0.5)],
            icon: "star.fill", highlight: "🌟",
            title: "继续记录吧", subtitle: "每一个碎片，都是你独特的印记"
        ))

        return result
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

    private func computeStreak() -> Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var count = 0
        let daySet = Set(fragments.map { cal.startOfDay(for: $0.date) })
        while daySet.contains(day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
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
