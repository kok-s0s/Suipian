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

    var currentDaysUntil: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if isRecurring {
            let thisYear = cal.component(.year, from: today)
            var comps = cal.dateComponents([.month, .day], from: date)
            comps.year = thisYear
            if let thisOccurrence = cal.date(from: comps) {
                let start = cal.startOfDay(for: thisOccurrence)
                if start >= today {
                    return cal.dateComponents([.day], from: today, to: start).day ?? 0
                }
            }
            comps.year = thisYear + 1
            if let nextOccurrence = cal.date(from: comps) {
                let start = cal.startOfDay(for: nextOccurrence)
                return cal.dateComponents([.day], from: today, to: start).day ?? 0
            }
            return daysUntil
        }

        let target = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: today, to: target).day ?? daysUntil
    }
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
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
        let nextRefresh = tomorrow?.addingTimeInterval(60) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func load() -> [WidgetImportantDateData] {
        guard let defaults = UserDefaults(suiteName: kAppGroupID),
              let data = defaults.data(forKey: kImportantDatesKey),
              let decoded = try? JSONDecoder().decode([WidgetImportantDateData].self, from: data) else {
            return []
        }
        return decoded
            .filter { $0.isRecurring || $0.currentDaysUntil >= 0 }
            .sorted { $0.currentDaysUntil < $1.currentDaysUntil }
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
                                Text(item.currentDaysUntil == 0 ? "今天" : "\(item.currentDaysUntil)天")
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
            if item.currentDaysUntil == 0 {
                Text("今天")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            } else {
                Text("\(item.currentDaysUntil)")
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
