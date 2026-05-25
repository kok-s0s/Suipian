import WidgetKit
import SwiftUI

// MARK: - Shared data model

private let kAppGroupID = "group.com.kok-s0s.Suipian"
private let kLatestFragmentKey = "latestFragment"

struct WidgetFragmentData: Codable {
    let content: String
    let date: Date
    let locationName: String
    let tags: [String]
}

// MARK: - Timeline provider

struct FragmentEntry: TimelineEntry {
    let date: Date
    let fragment: WidgetFragmentData?
}

struct FragmentTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FragmentEntry {
        FragmentEntry(date: Date(), fragment: WidgetFragmentData(
            content: "记录生活中的每一个瞬间",
            date: Date(),
            locationName: "上海",
            tags: ["生活"]
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (FragmentEntry) -> Void) {
        completion(FragmentEntry(date: Date(), fragment: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FragmentEntry>) -> Void) {
        let entry = FragmentEntry(date: Date(), fragment: load())
        completion(Timeline(entries: [entry], policy: .atEnd))
    }

    private func load() -> WidgetFragmentData? {
        // Try App Group shared container first; fall back gracefully if not provisioned
        if let defaults = UserDefaults(suiteName: kAppGroupID),
           let data = defaults.data(forKey: kLatestFragmentKey),
           let decoded = try? JSONDecoder().decode(WidgetFragmentData.self, from: data) {
            return decoded
        }
        return nil
    }
}

// MARK: - Widget view

struct SuipianWidgetEntryView: View {
    let entry: FragmentEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let f = entry.fragment {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("碎片")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Text(f.date.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 6)

                Text(f.content.isEmpty ? "（无文字内容）" : f.content)
                    .font(family == .systemSmall ? .caption : .subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(family == .systemSmall ? 5 : 7)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    if !f.locationName.isEmpty {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                        Text(f.locationName).lineLimit(1)
                    } else if let tag = f.tags.first {
                        Text("#\(tag)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "square.on.square")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor.opacity(0.6))
                Text("还没有碎片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Widget definition

struct SuipianWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.kok-s0s.Suipian.latestFragment",
            provider: FragmentTimelineProvider()
        ) { entry in
            SuipianWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("最新碎片")
        .description("在主屏幕查看你最近记录的碎片")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
