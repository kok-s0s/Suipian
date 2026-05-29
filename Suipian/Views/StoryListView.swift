import SwiftUI
import SwiftData

// MARK: - Story list (tab)

struct StoryListView: View {
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]

    private var stories: [(name: String, fragments: [Fragment])] {
        var dict: [String: [Fragment]] = [:]
        for f in fragments where !f.storyName.isEmpty {
            dict[f.storyName, default: []].append(f)
        }
        return dict.sorted {
            ($0.value.first?.date ?? .distantPast) > ($1.value.first?.date ?? .distantPast)
        }.map { (name: $0.key, fragments: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if stories.isEmpty {
                    ContentUnavailableView(
                        "还没有故事线",
                        systemImage: "link.badge.plus",
                        description: Text("编辑碎片时填写「关联到故事线」，多条碎片共用同一名称就会自动归组")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(stories, id: \.name) { story in
                                NavigationLink {
                                    StoryDetailView(name: story.name, fragments: story.fragments)
                                } label: {
                                    StoryCard(name: story.name, fragments: story.fragments)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 100)
                    }
                    .background { AppBackgroundCanvas().ignoresSafeArea() }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
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
        ZStack(alignment: .bottomLeading) {
            // Background: mosaic or gradient fallback
            if coverIDs.isEmpty {
                LinearGradient(
                    colors: [Color(red: 0.40, green: 0.28, blue: 0.52), Color(red: 0.26, green: 0.17, blue: 0.38)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            } else {
                StoryMosaicBackground(ids: coverIDs)
            }

            // Bottom scrim for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Text overlay
            VStack(alignment: .leading, spacing: 4) {
                Text("\(fragments.count) 条碎片  ·  \(dateRange)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                Text(name)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)

            // Top-right chevron badge
            Image(systemName: "chevron.right")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
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

    var body: some View {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newName = name
                    showingRename = true
                } label: {
                    Image(systemName: "pencil")
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
    }
}
