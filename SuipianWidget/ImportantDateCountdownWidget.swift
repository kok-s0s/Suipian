import WidgetKit
import SwiftUI

private let kAppGroupID = "group.com.kok-s0s.Suipian"
private let kImportantDatesKey = "importantDates"

struct WidgetImportantDateData: Codable {
    let title: String
    let date: Date
    let emoji: String
    let category: String
    let isRecurring: Bool
    let daysUntil: Int

    var stableID: String { "\(title)-\(date.timeIntervalSinceReferenceDate)" }
}

struct ImportantDateEntry: TimelineEntry {
    let date: Date
    let dates: [WidgetImportantDateData]
}

struct ImportantDateCountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> ImportantDateEntry {
        ImportantDateEntry(date: Date(), dates: [
            WidgetImportantDateData(title: "纪念日", date: Date(), emoji: "💕",
                                    category: "纪念日", isRecurring: true, daysUntil: 12)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ImportantDateEntry) -> Void) {
        completion(ImportantDateEntry(date: Date(), dates: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ImportantDateEntry>) -> Void) {
        let entry = ImportantDateEntry(date: Date(), dates: load())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func load() -> [WidgetImportantDateData] {
        guard let defaults = UserDefaults(suiteName: kAppGroupID),
              let data = defaults.data(forKey: kImportantDatesKey),
              let decoded = try? JSONDecoder().decode([WidgetImportantDateData].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.daysUntil < $1.daysUntil }
    }
}

struct ImportantDateCountdownWidgetView: View {
    let entry: ImportantDateEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let first = entry.dates.first {
            VStack(alignment: .leading, spacing: 10) {
                header

                HStack(alignment: .center, spacing: 10) {
                    Text(first.emoji)
                        .font(.system(size: family == .systemSmall ? 30 : 34))
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(first.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(subtitle(for: first))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                countdown(for: first)

                if family != .systemSmall {
                    Divider()
                    VStack(spacing: 5) {
                        ForEach(entry.dates.dropFirst().prefix(3), id: \.stableID) { item in
                            HStack(spacing: 6) {
                                Text(item.emoji)
                                Text(item.title)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.daysUntil == 0 ? "今天" : "\(item.daysUntil)天")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("还没有重要日期")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack {
            Text("日期倒计时")
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(Color(red: 0.780, green: 0.624, blue: 0.384))
            Spacer()
            Text(entry.date, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func countdown(for item: WidgetImportantDateData) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            if item.daysUntil == 0 {
                Text("今天")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            } else {
                Text("\(item.daysUntil)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("天后")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func subtitle(for item: WidgetImportantDateData) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return "\(item.category) · \(formatter.string(from: item.date))"
    }
}

struct ImportantDateCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.kok-s0s.Suipian.importantDateCountdown",
            provider: ImportantDateCountdownProvider()
        ) { entry in
            ImportantDateCountdownWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("日期倒计时")
        .description("在主屏幕查看最近的重要日期倒计时")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
