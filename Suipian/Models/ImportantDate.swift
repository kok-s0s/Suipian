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
    var notificationEnabled: Bool = true
    var createdAt: Date = Date()

    init(title: String, date: Date, emoji: String = "🗓",
         category: String = "纪念日", note: String = "",
         isRecurring: Bool = true, notificationEnabled: Bool = true) {
        self.title = title
        self.date = date
        self.emoji = emoji
        self.category = category
        self.note = note
        self.isRecurring = isRecurring
        self.notificationEnabled = notificationEnabled
    }

    static let categories = ["生日", "纪念日", "节日", "目标", "其他"]
    static let defaultEmojis = ["🎂", "💕", "🎉", "🌟", "📅", "🏆", "❤️", "🎊", "🗓", "✨"]
}

// MARK: - Countdown helpers

extension ImportantDate {
    /// Days until next occurrence (negative = already passed this year, non-recurring only)
    var daysUntil: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if isRecurring {
            // Find next occurrence: try this year first, then next year
            let thisYear = cal.component(.year, from: today)
            var comps = cal.dateComponents([.month, .day], from: date)
            comps.year = thisYear
            if let thisOccurrence = cal.date(from: comps) {
                let start = cal.startOfDay(for: thisOccurrence)
                if start >= today {
                    return cal.dateComponents([.day], from: today, to: start).day ?? 0
                }
                comps.year = thisYear + 1
                if let nextOccurrence = cal.date(from: comps) {
                    let start2 = cal.startOfDay(for: nextOccurrence)
                    return cal.dateComponents([.day], from: today, to: start2).day ?? 0
                }
            }
            return 0
        } else {
            let target = cal.startOfDay(for: date)
            return cal.dateComponents([.day], from: today, to: target).day ?? 0
        }
    }

    var isToday: Bool { daysUntil == 0 }
    var isPast: Bool { !isRecurring && daysUntil < 0 }

    var countdownLabel: String {
        let d = daysUntil
        if d == 0 { return "今天" }
        if d > 0  { return "还有 \(d) 天" }
        return "已过 \(-d) 天"
    }

    /// Years elapsed for recurring dates (anniversary / age)
    var yearsElapsed: Int? {
        guard isRecurring else { return nil }
        let cal = Calendar.current
        let years = cal.dateComponents([.year], from: date, to: Date()).year ?? 0
        return max(0, years)
    }
}
