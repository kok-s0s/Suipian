import SwiftUI
import SwiftData

// MARK: - Drill-down payload

struct FragmentDrillDown: Identifiable {
    let id = UUID()
    let title: String
    let fragments: [Fragment]
}

// MARK: - Stats root

struct StatsView: View {
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]
    @State private var drillDown: FragmentDrillDown?

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
                        SummaryCardsSection(fragments: fragments, onDrillDown: { drillDown = $0 })
                        StreakSection(fragments: fragments, onDrillDown: { drillDown = $0 })
                        HeatmapSection(fragments: fragments, onDrillDown: { drillDown = $0 })
                        MoodTrendSection(fragments: fragments, onDrillDown: { drillDown = $0 })
                        MoodStatsSection(fragments: fragments, onDrillDown: { drillDown = $0 })
                        TopTagsSection(fragments: fragments, onDrillDown: { drillDown = $0 })
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
                .background { AppBackgroundCanvas().ignoresSafeArea() }
            }
          }
          .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $drillDown) { item in
            FragmentListSheet(title: item.title, fragments: item.fragments)
        }
    }
}

// MARK: - Drill-down sheet

private struct FragmentListSheet: View {
    let title: String
    let fragments: [Fragment]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if fragments.isEmpty {
                    ContentUnavailableView("没有碎片", systemImage: "square.on.square.dashed")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(fragments) { fragment in
                                NavigationLink {
                                    FragmentDetailView(fragment: fragment)
                                } label: {
                                    FragmentCardView(fragment: fragment)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Summary cards

private struct SummaryCardsSection: View {
    let fragments: [Fragment]
    let onDrillDown: (FragmentDrillDown) -> Void

    private var weekFragments: [Fragment] {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date()))!
        return fragments.filter { $0.date >= start }
    }

    private var monthFragments: [Fragment] {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        let start = Calendar.current.date(from: comps)!
        return fragments.filter { $0.date >= start }
    }

    var body: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(fragments.count)", label: "总碎片", hint: "查看全部") {
                onDrillDown(FragmentDrillDown(title: "全部碎片", fragments: fragments))
            }
            StatCard(value: "\(monthFragments.count)", label: "本月新增", hint: "查看本月") {
                onDrillDown(FragmentDrillDown(title: "本月碎片", fragments: monthFragments))
            }
            StatCard(value: "\(weekFragments.count)", label: "近 7 天", hint: "查看近期") {
                onDrillDown(FragmentDrillDown(title: "最近 7 天", fragments: weekFragments))
            }
        }
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hint)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.accentColor.opacity(0.6))
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Streak

private struct StreakSection: View {
    let fragments: [Fragment]
    let onDrillDown: (FragmentDrillDown) -> Void

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

    private var streakFragments: [Fragment] {
        guard streak > 0 else { return [] }
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -(streak - 1), to: cal.startOfDay(for: Date()))!
        return fragments.filter { $0.date >= cutoff }
    }

    var body: some View {
        Button {
            guard streak > 0 else { return }
            onDrillDown(FragmentDrillDown(title: "连续 \(streak) 天", fragments: streakFragments))
        } label: {
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
                if streak > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .animeSecondaryCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Heatmap

private struct HeatmapSection: View {
    let fragments: [Fragment]
    let onDrillDown: (FragmentDrillDown) -> Void

    private let columns = 13
    private let rows = 7

    private var fragmentsByDay: [Date: [Fragment]] {
        let cal = Calendar.current
        var result: [Date: [Fragment]] = [:]
        for f in fragments {
            let d = cal.startOfDay(for: f.date)
            result[d, default: []].append(f)
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

            let byDay = fragmentsByDay
            let start = startDate
            let cal = Calendar.current
            let maxCount = max(1, byDay.values.map(\.count).max() ?? 1)

            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<columns, id: \.self) { col in
                    VStack(spacing: 4) {
                        ForEach(0..<rows, id: \.self) { row in
                            let day = cal.date(byAdding: .day, value: col * 7 + row, to: start)!
                            let dayFragments = byDay[day] ?? []
                            let count = dayFragments.count
                            let isFuture = day > Date()

                            RoundedRectangle(cornerRadius: 3)
                                .fill(isFuture
                                      ? Color.clear
                                      : count == 0
                                        ? Color.accentColor.opacity(0.08)
                                        : Color.accentColor.opacity(0.2 + 0.8 * Double(count) / Double(maxCount)))
                                .frame(width: 18, height: 18)
                                .onTapGesture {
                                    guard !isFuture, count > 0 else { return }
                                    let label = day.formatted(date: .abbreviated, time: .omitted)
                                    onDrillDown(FragmentDrillDown(title: label, fragments: dayFragments))
                                }
                        }
                    }
                }
            }

            HStack {
                Text("少").font(.caption2).foregroundStyle(.tertiary)
                HStack(spacing: 3) {
                    ForEach([0.08, 0.3, 0.55, 0.8, 1.0], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(opacity))
                            .frame(width: 12, height: 12)
                    }
                }
                Text("多").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("点击格子可查看当天碎片")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .animeSecondaryCard(cornerRadius: 14)
    }
}

// MARK: - Mood trend

private struct MoodTrendSection: View {
    let fragments: [Fragment]
    let onDrillDown: (FragmentDrillDown) -> Void

    private var last14Days: [(date: Date, mood: String?, dayFragments: [Fragment])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var byDay: [Date: [Fragment]] = [:]
        for f in fragments {
            let d = cal.startOfDay(for: f.date)
            byDay[d, default: []].append(f)
        }
        var dayMoods: [Date: String] = [:]
        for f in fragments where !f.mood.isEmpty {
            let d = cal.startOfDay(for: f.date)
            if dayMoods[d] == nil { dayMoods[d] = f.mood }
        }
        return (0..<14).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date: d, mood: dayMoods[d], dayFragments: byDay[d] ?? [])
        }
    }

    private var hasMoodData: Bool { last14Days.contains { $0.mood != nil } }

    var body: some View {
        if hasMoodData {
            VStack(alignment: .leading, spacing: 12) {
                Text("近 14 天情绪")
                    .font(.subheadline).fontWeight(.semibold)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(last14Days, id: \.date) { item in
                            Button {
                                guard !item.dayFragments.isEmpty else { return }
                                let label = item.date.formatted(date: .abbreviated, time: .omitted)
                                onDrillDown(FragmentDrillDown(title: label, fragments: item.dayFragments))
                            } label: {
                                VStack(spacing: 4) {
                                    if let mood = item.mood {
                                        Text(mood)
                                            .font(.title3)
                                            .frame(width: 34, height: 34)
                                            .background(Color.accentColor.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(UIColor.systemGray5))
                                            .frame(width: 34, height: 34)
                                    }
                                    Text(item.date, format: .dateTime.month(.twoDigits).day())
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .opacity(item.dayFragments.isEmpty ? 0.4 : 1)
                        }
                    }
                }
            }
            .padding(16)
            .animeSecondaryCard(cornerRadius: 14)
        }
    }
}

// MARK: - Mood stats (compact horizontal bubbles with arc)

private struct MoodStatsSection: View {
    let fragments: [Fragment]
    let onDrillDown: (FragmentDrillDown) -> Void

    private var moodGroups: [(emoji: String, fragments: [Fragment])] {
        var groups: [String: [Fragment]] = [:]
        for f in fragments where !f.mood.isEmpty {
            groups[f.mood, default: []].append(f)
        }
        return groups.sorted { $0.value.count > $1.value.count }
            .map { (emoji: $0.key, fragments: $0.value) }
    }

    var body: some View {
        if moodGroups.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("情绪分布")
                    .font(.subheadline).fontWeight(.semibold)

                let maxCount = Double(moodGroups.first?.fragments.count ?? 1)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(moodGroups, id: \.emoji) { item in
                            Button {
                                onDrillDown(FragmentDrillDown(title: "\(item.emoji) 的碎片", fragments: item.fragments))
                            } label: {
                                VStack(spacing: 5) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.accentColor.opacity(0.12), lineWidth: 3.5)
                                        Circle()
                                            .trim(from: 0, to: CGFloat(item.fragments.count) / maxCount)
                                            .stroke(Color.accentColor.opacity(0.72),
                                                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                            .rotationEffect(.degrees(-90))
                                        Text(item.emoji).font(.title3)
                                    }
                                    .frame(width: 50, height: 50)

                                    Text("\(item.fragments.count)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .animeSecondaryCard(cornerRadius: 14)
        }
    }
}

// MARK: - Top tags (flow wrap chips)

private struct TopTagsSection: View {
    let fragments: [Fragment]
    let onDrillDown: (FragmentDrillDown) -> Void

    private var topTags: [(tag: String, fragments: [Fragment])] {
        var groups: [String: [Fragment]] = [:]
        for f in fragments {
            for t in f.tags { groups[t, default: []].append(f) }
        }
        return groups.sorted { $0.value.count > $1.value.count }
            .prefix(12)
            .map { (tag: $0.key, fragments: $0.value) }
    }

    var body: some View {
        if topTags.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("常用标签")
                    .font(.subheadline).fontWeight(.semibold)

                FlowLayout(spacing: 8) {
                    ForEach(topTags, id: \.tag) { item in
                        Button {
                            onDrillDown(FragmentDrillDown(title: "#\(item.tag)", fragments: item.fragments))
                        } label: {
                            HStack(spacing: 4) {
                                Text("#\(item.tag)")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(Color.accentColor)
                                    .lineLimit(1)
                                Text("\(item.fragments.count)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.55), Color.accentColor.opacity(0.15)],
                                    startPoint: .leading, endPoint: .trailing
                                ), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .animeSecondaryCard(cornerRadius: 14)
        }
    }
}

// MARK: - Flow layout (iOS 16+)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var rowW: CGFloat = 0
        var rowH: CGFloat = 0
        var totalH: CGFloat = 0

        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if rowW > 0, rowW + spacing + sz.width > maxW {
                totalH += rowH + spacing
                rowW = 0; rowH = 0
            }
            rowW += (rowW > 0 ? spacing : 0) + sz.width
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW, height: totalH + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0

        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + spacing + sz.width > bounds.maxX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            let px = x > bounds.minX ? x + spacing : x
            subview.place(at: CGPoint(x: px, y: y), proposal: .unspecified)
            x = px + sz.width
            rowH = max(rowH, sz.height)
        }
    }
}
