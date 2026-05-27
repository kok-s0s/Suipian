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
    @State private var showingWrapped = false

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
                        VStack(spacing: 14) {
                            WrappedBannerCard { showingWrapped = true }
                            SummaryCardsSection(fragments: fragments, onDrillDown: { drillDown = $0 })
                            HeatmapSection(fragments: fragments, onDrillDown: { drillDown = $0 })
                            MoodCurveSection(fragments: fragments, onDrillDown: { drillDown = $0 })
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
        .fullScreenCover(isPresented: $showingWrapped) {
            WrappedView(fragments: Array(fragments))
        }
    }
}

// MARK: - Wrapped banner

private struct WrappedBannerCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.75), .pink.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("年度 / 月度回放")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("回顾你的碎片故事")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .animeCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
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

// MARK: - Section header helper

@ViewBuilder
private func statSectionHeader(_ title: String, icon: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.accentColor.opacity(0.8))
        Text(title)
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(.primary)
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
        HStack(spacing: 10) {
            StatCard(icon: "square.on.square.fill", value: "\(fragments.count)", label: "总碎片") {
                onDrillDown(FragmentDrillDown(title: "全部碎片", fragments: fragments))
            }
            StatCard(icon: "calendar.badge.plus", value: "\(monthFragments.count)", label: "本月新增") {
                onDrillDown(FragmentDrillDown(title: "本月碎片", fragments: monthFragments))
            }
            StatCard(icon: "clock.arrow.circlepath", value: "\(weekFragments.count)", label: "近 7 天") {
                onDrillDown(FragmentDrillDown(title: "最近 7 天", fragments: weekFragments))
            }
        }
    }
}

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Heatmap (GitHub style)

private struct HeatmapSection: View {
    let fragments: [Fragment]
    let onDrillDown: (FragmentDrillDown) -> Void

    private let columns = 13
    private let rows = 7
    private let cellSize: CGFloat = 17
    private let gap: CGFloat = 3

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

    private func monthLabel(for col: Int, start: Date, cal: Calendar) -> String? {
        guard let day = cal.date(byAdding: .day, value: col * 7, to: start) else { return nil }
        let dayOfMonth = cal.component(.day, from: day)
        guard dayOfMonth <= 7 else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt.string(from: day)
    }

    private let dayLabels = ["一", "", "三", "", "五", "", "日"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statSectionHeader("记录热力图", icon: "calendar.badge.clock")

            let byDay = fragmentsByDay
            let start = startDate
            let cal = Calendar.current
            let maxCount = max(1, byDay.values.map(\.count).max() ?? 1)

            VStack(alignment: .leading, spacing: gap) {
                // Month labels row
                HStack(spacing: gap) {
                    Text("").frame(width: 14)
                    ForEach(0..<columns, id: \.self) { col in
                        Text(monthLabel(for: col, start: start, cal: cal) ?? "")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: cellSize, alignment: .leading)
                    }
                }

                // Day labels + grid
                HStack(alignment: .top, spacing: gap) {
                    VStack(spacing: gap) {
                        ForEach(0..<rows, id: \.self) { row in
                            Text(dayLabels[row])
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .frame(width: 14, height: cellSize, alignment: .trailing)
                        }
                    }

                    HStack(alignment: .top, spacing: gap) {
                        ForEach(0..<columns, id: \.self) { col in
                            VStack(spacing: gap) {
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
                                                : Color.accentColor.opacity(0.18 + 0.82 * Double(count) / Double(maxCount)))
                                        .frame(width: cellSize, height: cellSize)
                                        .onTapGesture {
                                            guard !isFuture, count > 0 else { return }
                                            let label = day.formatted(date: .abbreviated, time: .omitted)
                                            onDrillDown(FragmentDrillDown(title: label, fragments: dayFragments))
                                        }
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                Text("少").font(.caption2).foregroundStyle(.tertiary)
                HStack(spacing: 3) {
                    ForEach([0.08, 0.3, 0.55, 0.8, 1.0], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(opacity))
                            .frame(width: 11, height: 11)
                    }
                }
                Text("多").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("点击格子查看当日碎片")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .animeSecondaryCard(cornerRadius: 14)
    }
}

// MARK: - Mood bezier curve chart

private struct MoodCurveSection: View {
    let fragments: [Fragment]
    let onDrillDown: (FragmentDrillDown) -> Void

    private var data: [(date: Date, count: Int, mood: String?, dayFragments: [Fragment])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var byDay: [Date: [Fragment]] = [:]
        var dayMoods: [Date: String] = [:]
        for f in fragments {
            let d = cal.startOfDay(for: f.date)
            byDay[d, default: []].append(f)
            if !f.mood.isEmpty && dayMoods[d] == nil { dayMoods[d] = f.mood }
        }
        return (0..<14).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -(13 - offset), to: today) else { return nil }
            let dayF = byDay[d] ?? []
            return (date: d, count: dayF.count, mood: dayMoods[d], dayFragments: dayF)
        }
    }

    private var hasData: Bool { data.contains { $0.count > 0 } }

    var body: some View {
        if hasData {
            VStack(alignment: .leading, spacing: 10) {
                statSectionHeader("近 14 天趋势", icon: "chart.xyaxis.line")
                MoodCurveChart(data: data, onDrillDown: onDrillDown)
            }
            .padding(16)
            .animeSecondaryCard(cornerRadius: 14)
        }
    }
}

private struct MoodCurveChart: View {
    let data: [(date: Date, count: Int, mood: String?, dayFragments: [Fragment])]
    let onDrillDown: (FragmentDrillDown) -> Void

    private let chartH: CGFloat = 80
    private let topPad: CGFloat = 22
    private let bottomPad: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let maxCount = max(1, data.map(\.count).max() ?? 1)
            let pts = chartPoints(width: w, max: maxCount)
            let cps = controlPoints(pts)

            ZStack(alignment: .topLeading) {
                // Fill
                fillPath(pts: pts, cps: cps)
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.22), Color.accentColor.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))

                // Line
                curvePath(pts: pts, cps: cps)
                    .stroke(Color.accentColor.opacity(0.65),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Data points + mood emoji
                ForEach(0..<min(data.count, pts.count), id: \.self) { i in
                    let item = data[i]
                    let pt = pts[i]
                    Button {
                        guard !item.dayFragments.isEmpty else { return }
                        onDrillDown(FragmentDrillDown(
                            title: item.date.formatted(date: .abbreviated, time: .omitted),
                            fragments: item.dayFragments
                        ))
                    } label: {
                        VStack(spacing: 1) {
                            if let mood = item.mood {
                                Text(mood).font(.system(size: 11))
                            }
                            Circle()
                                .fill(item.count > 0 ? Color.accentColor : Color(.systemGray4))
                                .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(x: pt.x, y: pt.y - (item.mood != nil ? 10 : 0))
                }

                // Date labels
                ForEach(0..<data.count, id: \.self) { i in
                    if i % 3 == 0 {
                        let x = pts.indices.contains(i) ? pts[i].x : 0
                        Text(data[i].date, format: .dateTime.month(.twoDigits).day())
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .position(x: x, y: chartH + topPad + 10)
                    }
                }
            }
        }
        .frame(height: chartH + topPad + bottomPad)
    }

    private func chartPoints(width: CGFloat, max: Int) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        let step = width / CGFloat(data.count - 1)
        let usableH = chartH * 0.82
        return data.enumerated().map { i, item in
            let x = CGFloat(i) * step
            let norm = CGFloat(item.count) / CGFloat(max)
            let y = topPad + usableH * (1 - norm)
            return CGPoint(x: x, y: y)
        }
    }

    private func controlPoints(_ pts: [CGPoint]) -> [(CGPoint, CGPoint)] {
        let alpha: CGFloat = 0.35
        return (0..<max(0, pts.count - 1)).map { i in
            let p0 = i > 0 ? pts[i-1] : pts[i]
            let p1 = pts[i]
            let p2 = pts[i+1]
            let p3 = i < pts.count - 2 ? pts[i+2] : p2
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) * alpha,
                              y: p1.y + (p2.y - p0.y) * alpha)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) * alpha,
                              y: p2.y - (p3.y - p1.y) * alpha)
            return (cp1, cp2)
        }
    }

    private func curvePath(pts: [CGPoint], cps: [(CGPoint, CGPoint)]) -> Path {
        var path = Path()
        guard pts.count >= 2 else { return path }
        path.move(to: pts[0])
        for i in 0..<pts.count - 1 {
            path.addCurve(to: pts[i+1], control1: cps[i].0, control2: cps[i].1)
        }
        return path
    }

    private func fillPath(pts: [CGPoint], cps: [(CGPoint, CGPoint)]) -> Path {
        var path = curvePath(pts: pts, cps: cps)
        if let last = pts.last, let first = pts.first {
            path.addLine(to: CGPoint(x: last.x, y: chartH + topPad))
            path.addLine(to: CGPoint(x: first.x, y: chartH + topPad))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Mood stats

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
                statSectionHeader("情绪分布", icon: "face.smiling")

                let maxCount = Double(moodGroups.first?.fragments.count ?? 1)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(moodGroups, id: \.emoji) { item in
                            Button {
                                onDrillDown(FragmentDrillDown(title: "\(item.emoji) 的碎片",
                                                              fragments: item.fragments))
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
                    .padding(.horizontal, 2).padding(.vertical, 4)
                }
            }
            .padding(16)
            .animeSecondaryCard(cornerRadius: 14)
        }
    }
}

// MARK: - Top tags (readable chips, no gradient border)

private struct TopTagsSection: View {
    let fragments: [Fragment]
    let onDrillDown: (FragmentDrillDown) -> Void

    private var topTags: [(tag: String, fragments: [Fragment])] {
        var groups: [String: [Fragment]] = [:]
        for f in fragments {
            for t in f.tags { groups[t, default: []].append(f) }
        }
        return groups.sorted { $0.value.count > $1.value.count }
            .prefix(14)
            .map { (tag: $0.key, fragments: $0.value) }
    }

    var body: some View {
        if topTags.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 10) {
                statSectionHeader("常用标签", icon: "tag")

                FlowLayout(spacing: 8) {
                    ForEach(topTags, id: \.tag) { item in
                        Button {
                            onDrillDown(FragmentDrillDown(title: "#\(item.tag)", fragments: item.fragments))
                        } label: {
                            HStack(spacing: 5) {
                                Text("#\(item.tag)")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(Color.accentColor)
                                    .lineLimit(1)
                                Text("\(item.fragments.count)")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(Color.accentColor.opacity(0.55))
                            }
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.10), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.28), lineWidth: 0.8))
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

// MARK: - Flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var rowW: CGFloat = 0, rowH: CGFloat = 0, totalH: CGFloat = 0
        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if rowW > 0, rowW + spacing + sz.width > maxW {
                totalH += rowH + spacing; rowW = 0; rowH = 0
            }
            rowW += (rowW > 0 ? spacing : 0) + sz.width
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW, height: totalH + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
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
