import WidgetKit
import SwiftUI

private let kImportantDatesKey = "importantDates"

struct WidgetImportantDateData: Codable {
    let title: String
    let date: Date
    let emoji: String
    let category: String
    let isRecurring: Bool
    let recurrenceRule: String

    private enum CodingKeys: String, CodingKey {
        case title, date, emoji, category, isRecurring, recurrenceRule
    }

    init(title: String, date: Date, emoji: String, category: String, isRecurring: Bool, recurrenceRule: String? = nil) {
        self.title = title
        self.date = date
        self.emoji = emoji
        self.category = category
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule ?? (isRecurring ? "yearly" : "none")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        emoji = try container.decode(String.self, forKey: .emoji)
        category = try container.decode(String.self, forKey: .category)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
            ?? (isRecurring ? "yearly" : "none")
    }

    var stableID: String { "\(title)-\(date.timeIntervalSinceReferenceDate)" }

    var nextOccurrence: Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if recurrenceRule == "yearly" {
            let comps = cal.dateComponents([.month, .day], from: date)
            return cal.nextDate(after: today.addingTimeInterval(-1),
                                matching: comps,
                                matchingPolicy: .nextTime)
                .map { cal.startOfDay(for: $0) }
        }

        if recurrenceRule == "monthly" {
            let wantedDay = cal.component(.day, from: date)
            let monthStartComps = cal.dateComponents([.year, .month], from: today)
            guard let monthStart = cal.date(from: monthStartComps) else { return nil }
            for offset in 0...1 {
                guard let candidateMonth = cal.date(byAdding: .month, value: offset, to: monthStart) else { continue }
                let range = cal.range(of: .day, in: .month, for: candidateMonth)
                let maxDay = range?.count ?? wantedDay
                var comps = cal.dateComponents([.year, .month], from: candidateMonth)
                comps.day = min(wantedDay, maxDay)
                if let occurrence = cal.date(from: comps).map({ cal.startOfDay(for: $0) }),
                   occurrence >= today {
                    return occurrence
                }
            }
        }

        return cal.startOfDay(for: date)
    }

    var daysUntil: Int {
        guard let target = nextOccurrence else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var isPast: Bool {
        recurrenceRule == "none" && daysUntil < 0
    }

    var monthDayText: String {
        guard let target = nextOccurrence else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = recurrenceRule == "monthly" ? "每月d日" : "M月d日"
        return formatter.string(from: target)
    }

    var countdownText: String {
        if daysUntil == 0 { return "今天" }
        if daysUntil == 1 { return "明天" }
        return "\(daysUntil)天"
    }

    fileprivate var tone: CountdownTone {
        if daysUntil == 0 { return .today }
        if daysUntil <= 7 { return .soon }
        return .normal
    }
}

private enum CountdownTone {
    case today
    case soon
    case normal

    var accent: Color {
        switch self {
        case .today:
            return WidgetAnimePalette.sakura
        case .soon:
            return WidgetAnimePalette.star
        case .normal:
            return WidgetAnimePalette.primary
        }
    }

    var soft: Color { accent.opacity(0.16) }
}

struct ImportantDateEntry: TimelineEntry {
    let date: Date
    let dates: [WidgetImportantDateData]
}

struct ImportantDateCountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> ImportantDateEntry {
        ImportantDateEntry(date: Date(), dates: [
            WidgetImportantDateData(title: "旅行出发", date: Date().addingTimeInterval(86400 * 5), emoji: "✈️", category: "目标", isRecurring: false),
            WidgetImportantDateData(title: "纪念日", date: Date().addingTimeInterval(86400 * 18), emoji: "💕", category: "纪念日", isRecurring: true),
            WidgetImportantDateData(title: "妈妈生日", date: Date().addingTimeInterval(86400 * 42), emoji: "🎂", category: "生日", isRecurring: true)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ImportantDateEntry) -> Void) {
        completion(ImportantDateEntry(date: Date(), dates: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ImportantDateEntry>) -> Void) {
        let entry = ImportantDateEntry(date: Date(), dates: load())
        let nextRefresh = Calendar.current
            .date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))?
            .addingTimeInterval(60) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func load() -> [WidgetImportantDateData] {
        guard let defaults = AppGroupDefaults.make(),
              let data = defaults.data(forKey: kImportantDatesKey),
              let decoded = try? JSONDecoder().decode([WidgetImportantDateData].self, from: data) else {
            return []
        }
        return decoded
            .filter { !$0.isPast }
            .sorted { lhs, rhs in
                if lhs.daysUntil != rhs.daysUntil { return lhs.daysUntil < rhs.daysUntil }
                return lhs.title < rhs.title
            }
    }
}

struct ImportantDateCountdownWidgetView: View {
    let entry: ImportantDateEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let first = entry.dates.first {
                switch family {
                case .systemSmall:
                    SmallCountdownView(item: first)
                case .systemLarge:
                    LargeCountdownView(primary: first, items: Array(entry.dates.dropFirst().prefix(7)))
                default:
                    MediumCountdownView(primary: first, items: Array(entry.dates.dropFirst().prefix(3)))
                }
            } else {
                EmptyImportantDateWidgetView()
            }
        }
        .containerBackground(for: .widget) {
            WidgetDateBackground(colorScheme: colorScheme)
        }
    }
}

private struct SmallCountdownView: View {
    let item: WidgetImportantDateData
    @Environment(\.colorScheme) private var colorScheme

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(item.emoji)
                    .font(.system(size: 28))
                    .frame(width: 40, height: 40)
                    .background(item.tone.soft, in: Circle())
                Spacer()
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(item.tone.accent)
                    .frame(width: 24, height: 24)
                    .background(colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.55), in: Circle())
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text("\(item.category) · \(item.monthDayText)")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            CountdownNumber(item: item, compact: false)
        }
        .padding(14)
    }
}

private struct MediumCountdownView: View {
    let primary: WidgetImportantDateData
    let items: [WidgetImportantDateData]
    @Environment(\.colorScheme) private var colorScheme

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.secondary
    }
    private var tertiaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.secondary.opacity(0.55)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(primary.emoji)
                        .font(.system(size: 30))
                        .frame(width: 42, height: 42)
                        .background(primary.tone.soft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text("\(primary.category) · \(primary.monthDayText)")
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)
                CountdownNumber(item: primary, compact: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("接下来")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(secondaryText)
                if items.isEmpty {
                    Text("暂无其他日期")
                        .font(.caption)
                        .foregroundStyle(secondaryText.opacity(0.92))
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    ForEach(items, id: \.stableID) { item in
                        CompactDateRow(item: item)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 128, alignment: .leading)
        }
        .padding(14)
    }
}

private struct LargeCountdownView: View {
    let primary: WidgetImportantDateData
    let items: [WidgetImportantDateData]
    @Environment(\.colorScheme) private var colorScheme

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("最近的重要日期")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(secondaryText)
                    HStack(spacing: 10) {
                        Text(primary.emoji)
                            .font(.system(size: 34))
                            .frame(width: 48, height: 48)
                            .background(primary.tone.soft, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(primary.title)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text("\(primary.category) · \(primary.monthDayText)")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                        }
                    }
                }
                Spacer(minLength: 0)
                CountdownNumber(item: primary, compact: true)
            }

            Divider().opacity(0.55)

            VStack(spacing: 8) {
                ForEach(items, id: \.stableID) { item in
                    WideDateRow(item: item)
                }
                if items.isEmpty {
                    Text("暂无其他日期")
                        .font(.caption)
                        .foregroundStyle(secondaryText.opacity(0.92))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(16)
    }
}

private struct CountdownNumber: View {
    let item: WidgetImportantDateData
    var compact: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.secondary
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            if item.daysUntil == 0 {
                Text("今天")
                    .font(.system(size: compact ? 34 : 40, weight: .bold, design: .rounded))
                    .foregroundStyle(item.tone.accent)
            } else {
                Text("\(item.daysUntil)")
                    .font(.system(size: compact ? 42 : 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(item.tone.accent)
                Text("天后")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(secondaryText)
                    .padding(.bottom, compact ? 7 : 8)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct CompactDateRow: View {
    let item: WidgetImportantDateData
    @Environment(\.colorScheme) private var colorScheme

    private var tertiaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.secondary.opacity(0.55)
    }

    var body: some View {
        HStack(spacing: 7) {
            Text(item.emoji)
                .font(.caption)
                .frame(width: 22, height: 22)
                .background(item.tone.soft, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.monthDayText)
                    .font(.caption2)
                    .foregroundStyle(tertiaryText)
            }
            Spacer(minLength: 0)
            Text(item.countdownText)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(item.tone.accent)
                .monospacedDigit()
        }
    }
}

private struct WideDateRow: View {
    let item: WidgetImportantDateData
    @Environment(\.colorScheme) private var colorScheme

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.secondary
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(item.emoji)
                .font(.body)
                .frame(width: 30, height: 30)
                .background(item.tone.soft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(item.category) · \(item.monthDayText)")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }
            Spacer(minLength: 0)
            Text(item.countdownText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(item.tone.accent)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

private struct EmptyImportantDateWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.secondary
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundStyle(WidgetAnimePalette.primary)
            VStack(spacing: 3) {
                Text("还没有日期")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("在碎片里添加生日、纪念日或目标日")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetDateBackground: View {
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    colorScheme == .dark
                        ? Color(red: 0.04, green: 0.05, blue: 0.10)
                        : Color(red: 0.96, green: 0.98, blue: 1.00),
                    colorScheme == .dark
                        ? Color(red: 0.08, green: 0.10, blue: 0.18)
                        : Color(red: 0.99, green: 0.95, blue: 0.90),
                    colorScheme == .dark
                        ? WidgetAnimePalette.violet.opacity(0.16)
                        : WidgetAnimePalette.primary.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct ImportantDateCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.kok-s0s.Suipian.importantDateCountdown",
            provider: ImportantDateCountdownProvider()
        ) { entry in
            ImportantDateCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("日期倒计时")
        .description("查看最近的重要日期、生日和纪念日倒计时")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
