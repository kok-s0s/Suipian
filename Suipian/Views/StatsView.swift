import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]

    var body: some View {
        NavigationStack {
            Group {
                if fragments.isEmpty {
                    ContentUnavailableView(
                        "还没有任何碎片",
                        systemImage: "chart.bar.xaxis",
                        description: Text("开始记录碎片后，这里会展示你的统计数据")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            SummaryCardsSection(fragments: fragments)
                            StreakSection(fragments: fragments)
                            HeatmapSection(fragments: fragments)
                            MoodTrendSection(fragments: fragments)
                            MoodStatsSection(fragments: fragments)
                            TopTagsSection(fragments: fragments)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Summary cards

private struct SummaryCardsSection: View {
    let fragments: [Fragment]

    private var totalCount: Int { fragments.count }

    private var weekCount: Int {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date()))!
        return fragments.filter { $0.date >= start }.count
    }

    private var monthCount: Int {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        let start = Calendar.current.date(from: comps)!
        return fragments.filter { $0.date >= start }.count
    }

    var body: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(totalCount)", label: "总碎片")
            StatCard(value: "\(monthCount)", label: "本月新增")
            StatCard(value: "\(weekCount)", label: "近 7 天")
        }
    }
}

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.accentColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Streak

private struct StreakSection: View {
    let fragments: [Fragment]

    private var streak: Int {
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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .font(.system(size: 32))
                .foregroundStyle(streak > 0 ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("连续记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(streak) 天")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Heatmap (last 12 weeks, Mon-Sun columns)

private struct HeatmapSection: View {
    let fragments: [Fragment]

    private let columns = 13
    private let rows = 7

    private var counts: [Date: Int] {
        let cal = Calendar.current
        var result: [Date: Int] = [:]
        for f in fragments {
            let d = cal.startOfDay(for: f.date)
            result[d, default: 0] += 1
        }
        return result
    }

    private var startDate: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let endOfThisWeek = cal.date(byAdding: .day, value: 6 - daysSinceMonday, to: today)!
        return cal.date(byAdding: .day, value: -(columns * 7 - 1), to: endOfThisWeek)!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("记录热力图")
                .font(.subheadline).fontWeight(.semibold)

            let allCounts = counts
            let start = startDate
            let cal = Calendar.current
            let maxCount = max(1, allCounts.values.max() ?? 1)

            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<columns, id: \.self) { col in
                    VStack(spacing: 4) {
                        ForEach(0..<rows, id: \.self) { row in
                            let day = cal.date(byAdding: .day, value: col * 7 + row, to: start)!
                            let count = allCounts[day] ?? 0
                            let isFuture = day > Date()
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isFuture
                                      ? Color.clear
                                      : count == 0
                                        ? Color.accentColor.opacity(0.08)
                                        : Color.accentColor.opacity(0.2 + 0.8 * Double(count) / Double(maxCount)))
                                .frame(width: 18, height: 18)
                        }
                    }
                }
            }

            HStack {
                Text("少")
                    .font(.caption2).foregroundStyle(.tertiary)
                HStack(spacing: 3) {
                    ForEach([0.08, 0.3, 0.55, 0.8, 1.0], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(opacity))
                            .frame(width: 12, height: 12)
                    }
                }
                Text("多")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Mood trend (last 14 days)

private struct MoodTrendSection: View {
    let fragments: [Fragment]

    private var last14Days: [(date: Date, mood: String?)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var dayMoods: [Date: String] = [:]
        for f in fragments where !f.mood.isEmpty {
            let d = cal.startOfDay(for: f.date)
            if dayMoods[d] == nil { dayMoods[d] = f.mood }
        }
        return (0..<14).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date: d, mood: dayMoods[d])
        }
    }

    private var hasMoodData: Bool {
        last14Days.contains { $0.mood != nil }
    }

    var body: some View {
        if hasMoodData {
            VStack(alignment: .leading, spacing: 12) {
                Text("近 14 天情绪")
                    .font(.subheadline).fontWeight(.semibold)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(last14Days, id: \.date) { item in
                            VStack(spacing: 4) {
                                if let mood = item.mood {
                                    Text(mood)
                                        .font(.title3)
                                        .frame(width: 34, height: 34)
                                        .background(Color.accentColor.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 34, height: 34)
                                }
                                Text(item.date, format: .dateTime.month(.twoDigits).day())
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Mood stats

private struct MoodStatsSection: View {
    let fragments: [Fragment]

    private var moodCounts: [(emoji: String, count: Int)] {
        var freq: [String: Int] = [:]
        for f in fragments where !f.mood.isEmpty {
            freq[f.mood, default: 0] += 1
        }
        return freq.sorted { $0.value > $1.value }.map { (emoji: $0.key, count: $0.value) }
    }

    var body: some View {
        if moodCounts.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("情绪分布")
                    .font(.subheadline).fontWeight(.semibold)

                let maxCount = moodCounts.first?.count ?? 1
                ForEach(moodCounts, id: \.emoji) { item in
                    HStack(spacing: 10) {
                        Text(item.emoji).font(.title3).frame(width: 32)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.accentColor.opacity(0.1))
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.6))
                                    .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                            }
                        }
                        .frame(height: 8)

                        Text("\(item.count)")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Top tags

private struct TopTagsSection: View {
    let fragments: [Fragment]

    private var topTags: [(tag: String, count: Int)] {
        var freq: [String: Int] = [:]
        for f in fragments {
            for t in f.tags { freq[t, default: 0] += 1 }
        }
        return freq.sorted { $0.value > $1.value }.prefix(8).map { (tag: $0.key, count: $0.value) }
    }

    var body: some View {
        if topTags.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("常用标签")
                    .font(.subheadline).fontWeight(.semibold)

                let maxCount = topTags.first?.count ?? 1
                ForEach(topTags, id: \.tag) { item in
                    HStack(spacing: 10) {
                        Text("#\(item.tag)")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 100, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.1))
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                            }
                        }
                        .frame(height: 8)

                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
