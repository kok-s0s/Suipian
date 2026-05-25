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
                        LazyVStack(spacing: 16) {
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
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("故事线")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Story card

private struct StoryCard: View {
    let name: String
    let fragments: [Fragment]

    private var dateRange: String {
        guard let first = fragments.last?.date, let last = fragments.first?.date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return fmt.string(from: first)
        }
        return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(fragments.count) 条碎片 · \(dateRange)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Cover thumbnails (up to 4)
            HStack(spacing: 8) {
                ForEach(Array(fragments.prefix(4).enumerated()), id: \.offset) { _, f in
                    if let id = f.coverMediaID {
                        MediaThumbnailView(identifier: id, size: CGSize(width: 120, height: 120))
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(f.mood.isEmpty ? "📝" : f.mood)
                                    .font(.title3)
                            )
                    }
                }
                if fragments.count > 4 {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Text("+\(fragments.count - 4)")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        )
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(.label).opacity(0.06), radius: 8, y: 2)
    }
}

// MARK: - Story detail

struct StoryDetailView: View {
    let name: String
    let fragments: [Fragment]

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
    }
}
