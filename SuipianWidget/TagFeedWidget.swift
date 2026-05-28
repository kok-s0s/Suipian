import WidgetKit
import SwiftUI
import AppIntents

private let kAppGroupID = "group.com.kok-s0s.Suipian"

// MARK: - Cycle intent

struct NextTagFragmentIntent: AppIntent {
    static var title: LocalizedStringResource = "下一条碎片"

    @Parameter(title: "标签") var tag: String

    init() { tag = "" }
    init(tag: String) { self.tag = tag }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: kAppGroupID)
        let key = "widgetIndex_\(tag)"
        let fragments = Self.load(tag: tag, from: defaults)
        guard !fragments.isEmpty else { return .result() }
        let next = ((defaults?.integer(forKey: key) ?? 0) + 1) % fragments.count
        defaults?.set(next, forKey: key)
        return .result()
    }

    static func load(tag: String, from defaults: UserDefaults?) -> [WidgetFragmentData] {
        guard let defaults else { return [] }
        if tag.isEmpty {
            guard let data = defaults.data(forKey: "tagFragments_all"),
                  let list = try? JSONDecoder().decode([WidgetFragmentData].self, from: data)
            else { return [] }
            return list
        } else {
            guard let data = defaults.data(forKey: "tagFragmentsMap"),
                  let map = try? JSONDecoder().decode([String: [WidgetFragmentData]].self, from: data),
                  let list = map[tag]
            else { return [] }
            return list
        }
    }
}

// MARK: - Configuration intent

struct TagSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择标签"
    static var description = IntentDescription("选择要展示的标签，留空显示全部碎片")

    @Parameter(title: "标签（留空 = 全部）", default: "")
    var tag: String
}

// MARK: - Timeline provider

struct TagFeedEntry: TimelineEntry {
    let date: Date
    let fragment: WidgetFragmentData?
    let index: Int
    let total: Int
    let tag: String
}

struct TagFeedProvider: AppIntentTimelineProvider {
    typealias Entry = TagFeedEntry
    typealias Intent = TagSelectionIntent

    func placeholder(in context: Context) -> TagFeedEntry {
        TagFeedEntry(
            date: Date(),
            fragment: WidgetFragmentData(content: "今天遇见了什么？", date: Date(),
                                         locationName: "上海", tags: ["生活"]),
            index: 0, total: 3, tag: ""
        )
    }

    func snapshot(for configuration: TagSelectionIntent, in context: Context) async -> TagFeedEntry {
        makeEntry(for: configuration)
    }

    func timeline(for configuration: TagSelectionIntent, in context: Context) async -> Timeline<TagFeedEntry> {
        Timeline(entries: [makeEntry(for: configuration)], policy: .atEnd)
    }

    private func makeEntry(for configuration: TagSelectionIntent) -> TagFeedEntry {
        let tag = configuration.tag.trimmingCharacters(in: .whitespaces)
        let defaults = UserDefaults(suiteName: kAppGroupID)
        let fragments = NextTagFragmentIntent.load(tag: tag, from: defaults)
        let stored = defaults?.integer(forKey: "widgetIndex_\(tag)") ?? 0
        let index = fragments.isEmpty ? 0 : stored % fragments.count
        return TagFeedEntry(
            date: Date(),
            fragment: fragments.isEmpty ? nil : fragments[index],
            index: index,
            total: fragments.count,
            tag: tag
        )
    }
}

// MARK: - Widget view

struct TagFeedWidgetView: View {
    let entry: TagFeedEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let f = entry.fragment {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    Text(entry.tag.isEmpty ? "碎片" : "#\(entry.tag)")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    if entry.total > 1 {
                        Text("\(entry.index + 1) / \(entry.total)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom, 6)

                // Content
                Text(f.content.isEmpty ? "（无文字内容）" : f.content)
                    .font(family == .systemSmall ? .caption : .subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(family == .systemSmall ? 4 : 6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 4)

                // Footer
                HStack(alignment: .center) {
                    Group {
                        if !f.locationName.isEmpty {
                            Label(f.locationName, systemImage: "location.fill")
                        } else {
                            Text(f.date.formatted(.relative(presentation: .named)))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    Spacer()

                    if entry.total > 1 {
                        Button(intent: NextTagFragmentIntent(tag: entry.tag)) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 26, height: 26)
                                .background(Color.accentColor.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(spacing: 8) {
                Image(systemName: entry.tag.isEmpty ? "square.on.square.dashed" : "tag")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor.opacity(0.5))
                Text(entry.tag.isEmpty ? "还没有碎片" : "「\(entry.tag)」下还没有碎片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Widget definition

struct TagFeedWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "com.kok-s0s.Suipian.tagFeed",
            intent: TagSelectionIntent.self,
            provider: TagFeedProvider()
        ) { entry in
            TagFeedWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("碎片标签流")
        .description("按标签浏览碎片，点击右下角切换下一条")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
