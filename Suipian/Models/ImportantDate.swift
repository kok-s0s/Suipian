import Foundation
import SwiftData

@Model
final class ImportantDate {
    var title: String = ""
    var date: Date = Date()
    var emoji: String = "🗓"
    var category: String = "纪念日"
    var note: String = ""
    var isRecurring: Bool = true
    var recurrenceRuleRaw: String = "legacy"
    var notificationEnabled: Bool = true
    var advanceReminderDays: Int = 0
    var autoRecordFragment: Bool = true
    var createdAt: Date = Date()

    init(title: String, date: Date, emoji: String = "🗓",
         category: String = "纪念日", note: String = "",
         isRecurring: Bool = true, recurrenceRule: ImportantDateRecurrenceRule? = nil,
         notificationEnabled: Bool = true,
         advanceReminderDays: Int = 0,
         autoRecordFragment: Bool = true) {
        self.title = title
        self.date = date
        self.emoji = emoji
        self.category = category
        self.note = note
        let rule = recurrenceRule ?? (isRecurring ? .yearly : .none)
        self.recurrenceRuleRaw = rule.rawValue
        self.isRecurring = rule != .none
        self.notificationEnabled = notificationEnabled
        self.advanceReminderDays = advanceReminderDays
        self.autoRecordFragment = autoRecordFragment
    }

    static let categories = ["生日", "纪念日", "节日", "目标", "其他"]
    static let defaultEmojis = ["🎂", "💕", "🎉", "🌟", "📅", "🏆", "❤️", "🎊", "🗓", "✨"]
}

enum ImportantDateRecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case none
    case yearly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "不重复"
        case .yearly: return "每年"
        case .monthly: return "每月"
        }
    }

    var detail: String {
        switch self {
        case .none: return "只提醒一次"
        case .yearly: return "适合生日、纪念日"
        case .monthly: return "适合工资日、还款日"
        }
    }
}

// MARK: - Countdown helpers

extension ImportantDate {
    var recurrenceRule: ImportantDateRecurrenceRule {
        get {
            if let rule = ImportantDateRecurrenceRule(rawValue: recurrenceRuleRaw), recurrenceRuleRaw != "legacy" {
                return rule
            }
            return isRecurring ? .yearly : .none
        }
        set {
            recurrenceRuleRaw = newValue.rawValue
            isRecurring = newValue != .none
        }
    }

    /// Days until next occurrence (negative = already passed this year, non-recurring only)
    var daysUntil: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if recurrenceRule == .none {
            let target = cal.startOfDay(for: date)
            return cal.dateComponents([.day], from: today, to: target).day ?? 0
        }

        guard let target = nextOccurrence(onOrAfter: today) else { return 0 }
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var isToday: Bool { daysUntil == 0 }
    var isPast: Bool { recurrenceRule == .none && daysUntil < 0 }

    var countdownLabel: String {
        let d = daysUntil
        if d == 0 { return "今天" }
        if d > 0  { return "还有 \(d) 天" }
        return "已过 \(-d) 天"
    }

    /// Years elapsed for recurring dates (anniversary / age)
    var yearsElapsed: Int? {
        guard recurrenceRule == .yearly else { return nil }
        let cal = Calendar.current
        let years = cal.dateComponents([.year], from: date, to: Date()).year ?? 0
        return max(0, years)
    }

    var recurrenceLabel: String { recurrenceRule.title }

    var displayDateLabel: String {
        let formatter = DateFormatter()
        switch recurrenceRule {
        case .monthly:
            formatter.dateFormat = "每月d日"
            return formatter.string(from: date)
        case .yearly:
            formatter.dateFormat = "M月d日"
            return formatter.string(from: date)
        case .none:
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: date)
        }
    }

    func nextOccurrence(onOrAfter startDate: Date = Date()) -> Date? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)

        switch recurrenceRule {
        case .none:
            return cal.startOfDay(for: date)
        case .yearly:
            let thisYear = cal.component(.year, from: start)
            let source = cal.dateComponents([.month, .day], from: date)
            for year in [thisYear, thisYear + 1] {
                var comps = DateComponents()
                comps.year = year
                comps.month = source.month
                comps.day = source.day
                if let occurrence = cal.date(from: comps).map({ cal.startOfDay(for: $0) }),
                   occurrence >= start {
                    return occurrence
                }
            }
            return nil
        case .monthly:
            let wantedDay = cal.component(.day, from: date)
            let currentMonth = cal.dateComponents([.year, .month], from: start)
            guard let monthStart = cal.date(from: currentMonth) else { return nil }
            for offset in 0...1 {
                guard let candidateMonth = cal.date(byAdding: .month, value: offset, to: monthStart) else { continue }
                let occurrence = monthlyOccurrence(inMonthContaining: candidateMonth, day: wantedDay, calendar: cal)
                if occurrence >= start { return occurrence }
            }
            return nil
        }
    }

    private func monthlyOccurrence(inMonthContaining monthDate: Date, day: Int, calendar cal: Calendar) -> Date {
        let range = cal.range(of: .day, in: .month, for: monthDate)
        let maxDay = range?.count ?? day
        var comps = cal.dateComponents([.year, .month], from: monthDate)
        comps.day = min(day, maxDay)
        return cal.startOfDay(for: cal.date(from: comps) ?? monthDate)
    }
}
