import SwiftUI
import SwiftData

// MARK: - Story list (tab)

struct StoryListView: View {
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]

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

                                if let activeStory {
                                    NavigationLink {
                                        StoryDetailView(name: activeStory.name, fragments: activeStory.fragments)
                                    } label: {
                                        FeaturedStoryCard(name: activeStory.name, fragments: activeStory.fragments)
                                    }
                                    .buttonStyle(PressScaleButtonStyle())
                                }

                                HStack {
                                    Text("全部故事线")
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(stories.count) 条")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                ForEach(stories, id: \.name) { story in
                                    NavigationLink {
                                        StoryDetailView(name: story.name, fragments: story.fragments)
                                    } label: {
                                        StoryCard(name: story.name, fragments: story.fragments)
                                    }
                                    .buttonStyle(PressScaleButtonStyle())
                                }
                            }
                            .padding(16)
                            .padding(.bottom, 100)
                        }
                        .background { AppBackgroundCanvas().ignoresSafeArea() }
                    }
                }

                // FAB — create new story
                Button {
                    newStoryNameInput = ""
                    showingNewStoryAlert = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.18))
                            .frame(width: 70, height: 70)
                            .blur(radius: 8)
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle().strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                            )
                            .shadow(color: Color.black.opacity(0.16), radius: 10, y: 5)
                        Image(systemName: "plus")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
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
                    .foregroundStyle(Color(red: 0.780, green: 0.624, blue: 0.384))
                    .frame(width: 40, height: 40)
                    .background(Color(red: 0.780, green: 0.624, blue: 0.384).opacity(0.13), in: Circle())
            }

            HStack(spacing: 10) {
                StoryMetric(value: "\(stories.count)", label: "故事")
                StoryMetric(value: "\(storyFragmentCount)", label: "碎片")
                StoryMetric(value: activeStory.map { "\($0.fragments.count)" } ?? "0", label: "最近")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
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

// MARK: - Request token

private struct StoryCreateRequest: Identifiable {
    let id = UUID()
    let name: String
}

private struct StoryMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
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
                    colors: [Color(red: 0.36, green: 0.44, blue: 0.64), Color(red: 0.78, green: 0.62, blue: 0.38)],
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
                        colors: [Color.accentColor.opacity(0.55), Color(red: 0.780, green: 0.624, blue: 0.384).opacity(0.55)],
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
    @State private var showingRename = false
    @State private var newName = ""
    @State private var showingAddFragment = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(fragments) { fragment in
                    NavigationLink {
                        FragmentDetailView(fragment: fragment)
                    } label: {
                        FragmentCardView(fragment: fragment)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
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
