import SwiftUI
import SwiftData

// MARK: - Story list (tab)

struct StoryListView: View {
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]
    @Query private var importantDates: [ImportantDate]

    @State private var showingNewStoryAlert = false
    @State private var newStoryNameInput = ""
    @State private var createRequest: StoryCreateRequest? = nil

    private var stories: [(name: String, fragments: [Fragment])] {
        var dict: [String: [Fragment]] = [:]
        for f in fragments where !f.storyName.isEmpty {
            dict[f.storyName, default: []].append(f)
        }
        return dict.sorted {
            ($0.value.first?.date ?? .distantPast) > ($1.value.first?.date ?? .distantPast)
        }.map { (name: $0.key, fragments: $0.value) }
    }

    private var storyFragmentCount: Int {
        stories.reduce(0) { $0 + $1.fragments.count }
    }

    private var activeStory: (name: String, fragments: [Fragment])? {
        stories.first
    }

    private var otherStories: [(name: String, fragments: [Fragment])] {
        Array(stories.dropFirst())
    }

    private var relationshipTimelines: [RelationshipSummary] {
        var dict: [String: [Fragment]] = [:]
        for fragment in fragments {
            for tag in fragment.tags where !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                dict[tag, default: []].append(fragment)
            }
        }
        let sorted = dict
            .map { RelationshipSummary(name: $0.key, fragments: $0.value.sorted { $0.date > $1.date }) }
            .sorted {
                if $0.fragments.count != $1.fragments.count { return $0.fragments.count > $1.fragments.count }
                return ($0.fragments.first?.date ?? .distantPast) > ($1.fragments.first?.date ?? .distantPast)
            }
        let repeated = sorted.filter { $0.fragments.count >= 2 }
        return Array((repeated.isEmpty ? sorted : repeated).prefix(8))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if stories.isEmpty {
                        storyEmptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                storyDashboard

                                if !relationshipTimelines.isEmpty {
                                    storySectionHeader("关系时间线", detail: "从标签自动生成")
                                    RelationshipRail(items: relationshipTimelines,
                                                     importantDates: importantDates)
                                }

                                if let activeStory {
                                    storySectionHeader("最近更新", detail: "继续整理这条故事线")

                                    NavigationLink {
                                        StoryDetailView(name: activeStory.name, fragments: activeStory.fragments)
                                    } label: {
                                        FeaturedStoryCard(name: activeStory.name, fragments: activeStory.fragments)
                                    }
                                    .buttonStyle(PressScaleButtonStyle())
                                }

                                if !otherStories.isEmpty {
                                    storySectionHeader("更多故事线", detail: "\(otherStories.count) 条")

                                    ForEach(otherStories, id: \.name) { story in
                                        NavigationLink {
                                            StoryDetailView(name: story.name, fragments: story.fragments)
                                        } label: {
                                            StoryCard(name: story.name, fragments: story.fragments)
                                        }
                                        .buttonStyle(PressScaleButtonStyle())
                                    }
                                }
                            }
                            .padding(16)
                            .padding(.bottom, 100)
                        }
                        .background { AppBackgroundCanvas().ignoresSafeArea() }
                    }
                }

                StoryAddFAB {
                    newStoryNameInput = ""
                    showingNewStoryAlert = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("新建故事线", isPresented: $showingNewStoryAlert) {
            TextField("故事线名称，如「日本之旅」", text: $newStoryNameInput)
            Button("创建") {
                let name = newStoryNameInput.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                createRequest = StoryCreateRequest(name: name)
                newStoryNameInput = ""
            }
            Button("取消", role: .cancel) { newStoryNameInput = "" }
        } message: {
            Text("创建后可立即记录第一条碎片")
        }
        .sheet(item: $createRequest) { req in
            FragmentEditView(preloadedStoryName: req.name, saveDraftOnCancel: false)
        }
    }

    private var storyDashboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("故事线")
                        .font(.title2).fontWeight(.bold)
                    Text("把分散的碎片串成一段正在发生的经历")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(AnimePalette.star)
                    .frame(width: 40, height: 40)
                    .background(AnimePalette.softStar, in: Circle())
            }

            HStack(spacing: 10) {
                TabSummaryMetricCard(title: "故事", value: "\(stories.count)", icon: "sparkles", tint: AnimePalette.star)
                TabSummaryMetricCard(title: "碎片", value: "\(storyFragmentCount)", icon: "square.on.square", tint: AnimePalette.primary)
                TabSummaryMetricCard(title: "最近", value: activeStory.map { "\($0.fragments.count)" } ?? "0", icon: "clock.arrow.circlepath", tint: AnimePalette.violet)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func storySectionHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    private var storyEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "link.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                Text("还没有故事线")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text("把多条碎片串联成一个故事\n旅行、项目、成长，都可以是一条故事线")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                newStoryNameInput = ""
                showingNewStoryAlert = true
            } label: {
                Label("新建故事线", systemImage: "plus")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StoryAddFAB: View {
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 72, height: 72)
                    .blur(radius: 8)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)

                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("新建故事线")
    }
}

// MARK: - Request token

private struct StoryCreateRequest: Identifiable {
    let id = UUID()
    let name: String
}

private struct RelationshipSummary: Identifiable {
    let name: String
    let fragments: [Fragment]
    var id: String { name }

    var latest: Fragment? { fragments.first }
    var locationCount: Int {
        Set(fragments.compactMap { $0.locationName.isEmpty ? nil : $0.locationName }).count
    }
    var mediaCount: Int {
        fragments.reduce(0) { $0 + $1.mediaIdentifiers.count }
    }
}

private struct RelationshipRail: View {
    let items: [RelationshipSummary]
    let importantDates: [ImportantDate]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    NavigationLink {
                        RelationshipTimelineView(summary: item, importantDates: importantDates)
                    } label: {
                        RelationshipCard(summary: item)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct RelationshipCard: View {
    let summary: RelationshipSummary

    private var accent: Color {
        let palette = [AnimePalette.sakura, AnimePalette.primary, AnimePalette.violet, AnimePalette.mint, AnimePalette.star]
        let index = abs(summary.name.hashValue) % palette.count
        return palette[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(initialText)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(accent, in: Circle())
                Spacer()
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(accent)
                    .padding(7)
                    .background(accent.opacity(0.12), in: Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(latestText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Label("\(summary.fragments.count)", systemImage: "square.on.square")
                if summary.locationCount > 0 {
                    Label("\(summary.locationCount)", systemImage: "mappin.and.ellipse")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(width: 168, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(accent.opacity(0.18), lineWidth: 0.7))
    }

    private var initialText: String {
        String(summary.name.prefix(1)).uppercased()
    }

    private var latestText: String {
        guard let latest = summary.latest else { return "还没有共同碎片" }
        if !latest.content.isEmpty { return latest.content }
        if !latest.locationName.isEmpty { return latest.locationName }
        return latest.date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct RelationshipTimelineView: View {
    let summary: RelationshipSummary
    let importantDates: [ImportantDate]

    private var relatedDates: [ImportantDate] {
        importantDates
            .filter {
                $0.title.localizedCaseInsensitiveContains(summary.name)
                || $0.note.localizedCaseInsensitiveContains(summary.name)
            }
            .sorted { $0.daysUntil < $1.daysUntil }
    }

    private var topLocations: [(name: String, count: Int)] {
        var freq: [String: Int] = [:]
        for fragment in summary.fragments where !fragment.locationName.isEmpty {
            freq[fragment.locationName, default: 0] += 1
        }
        return Array(freq.sorted { $0.value > $1.value }.map { (name: $0.key, count: $0.value) }.prefix(3))
    }

    private var moodLine: String {
        let moods = summary.fragments.map(\.mood).filter { !$0.isEmpty }
        guard !moods.isEmpty else { return "暂无心情" }
        return Array(moods.prefix(5)).joined(separator: " ")
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                RelationshipHero(summary: summary,
                                 relatedDateCount: relatedDates.count,
                                 moodLine: moodLine)

                if !relatedDates.isEmpty {
                    relationshipSectionHeader("关联日期", detail: "\(relatedDates.count) 个")
                    VStack(spacing: 10) {
                        ForEach(Array(relatedDates.prefix(4))) { item in
                            RelationshipDateRow(item: item)
                        }
                    }
                }

                if !topLocations.isEmpty {
                    relationshipSectionHeader("常出现的地点", detail: "\(summary.locationCount) 个地点")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(topLocations, id: \.name) { loc in
                                Label("\(loc.name) \(loc.count)", systemImage: "location.fill")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                    }
                }

                relationshipSectionHeader("共同碎片", detail: "\(summary.fragments.count) 条")
                LazyVStack(spacing: 0) {
                    ForEach(Array(summary.fragments.enumerated()), id: \.offset) { index, fragment in
                        StoryTimelineRow(fragment: fragment,
                                         isFirst: index == 0,
                                         isLast: index == summary.fragments.count - 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .background { AppBackgroundCanvas().ignoresSafeArea() }
        .navigationTitle(summary.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func relationshipSectionHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }
}

private struct RelationshipHero: View {
    let summary: RelationshipSummary
    let relatedDateCount: Int
    let moodLine: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Text(String(summary.name.prefix(1)).uppercased())
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(AnimePalette.primary, in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.name)
                        .font(.title2).fontWeight(.bold)
                    Text("由 #\(summary.name) 标签生成")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                TabSummaryMetricCard(title: "碎片", value: "\(summary.fragments.count)", icon: "square.on.square", tint: AnimePalette.primary)
                TabSummaryMetricCard(title: "日期", value: "\(relatedDateCount)", icon: "calendar", tint: AnimePalette.sakura)
                TabSummaryMetricCard(title: "媒体", value: "\(summary.mediaCount)", icon: "photo", tint: AnimePalette.star)
            }

            Text(moodLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}

private struct RelationshipDateRow: View {
    let item: ImportantDate

    var body: some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.countdownLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct FeaturedStoryCard: View {
    let name: String
    let fragments: [Fragment]

    private var latest: Fragment? { fragments.first }
    private var coverIDs: [String] {
        Array(fragments.compactMap { $0.coverMediaID }.prefix(4))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if coverIDs.isEmpty {
                LinearGradient(
                    colors: AnimePalette.warmGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                StoryMosaicBackground(ids: coverIDs)
            }

            LinearGradient(colors: [.black.opacity(0.04), .black.opacity(0.72)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Text("最近更新")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.82))
                Text(name)
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let latest {
                    Text(latest.content.isEmpty ? "\(fragments.count) 条碎片" : latest.content)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Label("\(fragments.count)", systemImage: "square.on.square")
                    if let date = latest?.date {
                        Text(date.formatted(.relative(presentation: .named)))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }
}

// MARK: - Story card (hero poster style)

private struct StoryCard: View {
    let name: String
    let fragments: [Fragment]

    private var coverIDs: [String] {
        Array(fragments.compactMap { $0.coverMediaID }.prefix(4))
    }

    private var dateRange: String {
        guard let first = fragments.last?.date, let last = fragments.first?.date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        if Calendar.current.isDate(first, inSameDayAs: last) { return fmt.string(from: first) }
        return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let id = coverIDs.first {
                    MediaThumbnailView(identifier: id, size: CGSize(width: 116, height: 116))
                        .frame(width: 58, height: 58)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [AnimePalette.primary.opacity(0.58), AnimePalette.sakura.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(dateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(fragments.count) 条碎片")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
    }
}

// MARK: - Thumbnail mosaic background

private struct StoryMosaicBackground: View {
    let ids: [String]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let gap: CGFloat = 1.5

            switch ids.count {
            case 1:
                tile(ids[0], w: w, h: h)
            case 2:
                HStack(spacing: gap) {
                    tile(ids[0], w: (w - gap) / 2, h: h)
                    tile(ids[1], w: (w - gap) / 2, h: h)
                }
            case 3:
                HStack(spacing: gap) {
                    tile(ids[0], w: (w - gap) / 2, h: h)
                    VStack(spacing: gap) {
                        tile(ids[1], w: (w - gap) / 2, h: (h - gap) / 2)
                        tile(ids[2], w: (w - gap) / 2, h: (h - gap) / 2)
                    }
                }
            default:
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        tile(ids[0], w: (w - gap) / 2, h: (h - gap) / 2)
                        tile(ids[1], w: (w - gap) / 2, h: (h - gap) / 2)
                    }
                    HStack(spacing: gap) {
                        tile(ids[2], w: (w - gap) / 2, h: (h - gap) / 2)
                        tile(ids[3], w: (w - gap) / 2, h: (h - gap) / 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ id: String, w: CGFloat, h: CGFloat) -> some View {
        MediaThumbnailView(identifier: id, size: CGSize(width: w * 2, height: h * 2))
            .frame(width: w, height: h)
            .clipped()
    }
}

// MARK: - Story detail

struct StoryDetailView: View {
    let name: String
    let fragments: [Fragment]

    @Environment(\.modelContext) private var modelContext
    @AppStorage("storyDetailIsGrid") private var isGridView = false
    @State private var showingRename = false
    @State private var newName = ""
    @State private var showingAddFragment = false

    private var sortedFragments: [Fragment] {
        fragments.sorted { $0.date > $1.date }
    }

    private var coverIDs: [String] {
        Array(sortedFragments.compactMap { $0.coverMediaID }.prefix(4))
    }

    private var dateRange: String {
        guard let first = sortedFragments.last?.date, let last = sortedFragments.first?.date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        if Calendar.current.isDate(first, inSameDayAs: last) { return fmt.string(from: first) }
        return "\(fmt.string(from: first)) - \(fmt.string(from: last))"
    }

    private var locationCount: Int {
        Set(sortedFragments.compactMap { $0.locationName.isEmpty ? nil : $0.locationName }).count
    }

    private var mediaCount: Int {
        sortedFragments.reduce(0) { $0 + $1.mediaIdentifiers.count }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                StoryDetailHero(name: name,
                                coverIDs: coverIDs,
                                dateRange: dateRange,
                                fragmentCount: sortedFragments.count,
                                locationCount: locationCount,
                                mediaCount: mediaCount)

                HStack {
                    Text(isGridView ? "方格" : "时间轴")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(sortedFragments.count) 条碎片")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if isGridView {
                    StoryFragmentGrid(fragments: sortedFragments)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sortedFragments.enumerated()), id: \.offset) { index, fragment in
                            StoryTimelineRow(fragment: fragment,
                                             isFirst: index == 0,
                                             isLast: index == sortedFragments.count - 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .background { AppBackgroundCanvas().ignoresSafeArea() }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isGridView.toggle() }
                    } label: {
                        Image(systemName: isGridView ? "rectangle.grid.1x2" : "square.grid.2x2")
                            .glassToolbarIcon(active: isGridView)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingAddFragment = true
                    } label: {
                        Image(systemName: "plus")
                            .glassToolbarIcon()
                    }
                    .buttonStyle(.plain)

                    Button {
                        newName = name
                        showingRename = true
                    } label: {
                        Image(systemName: "pencil")
                            .glassToolbarIcon()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .alert("重命名故事线", isPresented: $showingRename) {
            TextField("故事线名称", text: $newName)
            Button("取消", role: .cancel) {}
            Button("确认") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, trimmed != name else { return }
                fragments.forEach { $0.storyName = trimmed }
                try? modelContext.save()
            }
        } message: {
            Text("将同时更新该故事线下所有碎片的关联名称")
        }
        .sheet(isPresented: $showingAddFragment) {
            FragmentEditView(preloadedStoryName: name, saveDraftOnCancel: false)
        }
    }
}

private struct StoryDetailHero: View {
    let name: String
    let coverIDs: [String]
    let dateRange: String
    let fragmentCount: Int
    let locationCount: Int
    let mediaCount: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if coverIDs.isEmpty {
                LinearGradient(
                    colors: AnimePalette.heroGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                StoryMosaicBackground(ids: coverIDs)
            }

            LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.74)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(dateRange)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.80))
                    Text(name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    StoryHeroMetric(value: "\(fragmentCount)", label: "碎片")
                    StoryHeroMetric(value: "\(locationCount)", label: "地点")
                    StoryHeroMetric(value: "\(mediaCount)", label: "媒体")
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }
}

private struct StoryHeroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct StoryFragmentGrid: View {
    let fragments: [Fragment]

    private var leftItems: [Fragment] {
        fragments.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
    }

    private var rightItems: [Fragment] {
        fragments.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(leftItems) { fragment in
                    StoryGridFragmentCard(fragment: fragment)
                }
            }
            LazyVStack(spacing: 12) {
                ForEach(rightItems) { fragment in
                    StoryGridFragmentCard(fragment: fragment)
                }
            }
        }
    }
}

private struct StoryGridFragmentCard: View {
    let fragment: Fragment

    var body: some View {
        NavigationLink {
            FragmentDetailView(fragment: fragment)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if fragment.isPrivate {
                    privateCover
                } else if let id = fragment.coverMediaID {
                    MediaThumbnailView(identifier: id, size: CGSize(width: 260, height: 260))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                } else {
                    textBlock
                }

                VStack(alignment: .leading, spacing: 6) {
                    if !fragment.content.isEmpty, fragment.coverMediaID != nil, !fragment.isPrivate {
                        Text(fragment.content)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }

                    HStack(spacing: 5) {
                        if !fragment.mood.isEmpty {
                            Text(fragment.mood)
                        }
                        Text(fragment.date.formatted(date: .abbreviated, time: .omitted))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if !fragment.tags.isEmpty && !fragment.isPrivate {
                        HStack(spacing: 4) {
                            ForEach(fragment.tags.prefix(2), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.accentColor)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
    }

    private var privateCover: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text("私密碎片")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 112)
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !fragment.mood.isEmpty {
                Text(fragment.mood)
                    .font(.title3)
            }
            Text(fragment.content.isEmpty ? "（无文字内容）" : fragment.content)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(7)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(Color.accentColor.opacity(0.06))
    }
}

private struct StoryTimelineRow: View {
    let fragment: Fragment
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Color.accentColor.opacity(0.22))
                    .frame(width: 2, height: 14)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 9, height: 9)
                Rectangle()
                    .fill(isLast ? Color.clear : Color.accentColor.opacity(0.22))
                    .frame(width: 2)
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(fragment.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    if !fragment.locationName.isEmpty {
                        Label(fragment.locationName, systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                NavigationLink {
                    FragmentDetailView(fragment: fragment)
                } label: {
                    FragmentCardView(fragment: fragment)
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(.bottom, isLast ? 0 : 14)
        }
    }
}
