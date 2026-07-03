import UserNotifications
import Foundation
import SwiftData

enum ImportantDateNotifier {
    private static let prefix = "important-date-"

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        if status == .authorized || status == .provisional { return true }
        if status == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        return false
    }

    static func rescheduleAll(_ dates: [ImportantDate]) {
        let center = UNUserNotificationCenter.current()
        // Remove all important-date notifications first
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
            for d in dates where d.notificationEnabled { schedule(d) }
        }
    }

    static func schedule(_ item: ImportantDate) {
        guard item.notificationEnabled else { return }

        if item.advanceReminderDays > 0 {
            scheduleKind(item, kind: .advance(days: item.advanceReminderDays))
        }
        scheduleKind(item, kind: .dayOf)
    }

    private static func scheduleKind(_ item: ImportantDate, kind: ReminderKind) {
        if item.recurrenceRule == .monthly {
            scheduleMonthly(item, kind: kind)
            return
        }
        guard let triggerDate = triggerDateComponents(for: item, kind: kind) else { return }
        addRequest(item: item, kind: kind, identifier: "\(baseID(for: item))-\(kind.identifier)",
                   triggerDate: triggerDate, repeats: item.recurrenceRule == .yearly)
    }

    private static func scheduleMonthly(_ item: ImportantDate, kind: ReminderKind) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let wantedDay = cal.component(.day, from: item.date)
        let monthStartComps = cal.dateComponents([.year, .month], from: today)
        guard let monthStart = cal.date(from: monthStartComps) else { return }

        var scheduled = 0
        for offset in 0..<8 {
            guard let candidateMonth = cal.date(byAdding: .month, value: offset, to: monthStart) else { continue }
            let occurrence = monthlyOccurrence(inMonthContaining: candidateMonth, day: wantedDay, calendar: cal)
            let fireDate: Date
            switch kind {
            case .dayOf:
                fireDate = occurrence
            case .advance(let days):
                guard let advanceDate = cal.date(byAdding: .day, value: -days, to: occurrence) else { continue }
                fireDate = cal.startOfDay(for: advanceDate)
            }
            guard fireDate >= today else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: fireDate)
            comps.hour = 9
            comps.minute = 0
            addRequest(item: item, kind: kind,
                       identifier: "\(baseID(for: item))-\(kind.identifier)-\(scheduled)",
                       triggerDate: comps,
                       repeats: false)
            scheduled += 1
            if scheduled >= 6 { break }
        }
    }

    private static func addRequest(item: ImportantDate, kind: ReminderKind, identifier: String,
                                   triggerDate: DateComponents, repeats: Bool) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["importantDateID": "\(item.persistentModelID)", "reminderKind": kind.identifier]

        switch kind {
        case .dayOf:
            content.title = "\(item.emoji) 今天是 \(item.title)"
            if item.recurrenceRule == .yearly, let years = item.yearsElapsed, years > 0 {
                content.body = "今天是第 \(years + 1) 年，打开碎片记录这个特别的日子。"
            } else {
                content.body = "打开碎片，记录这个特别的日子。"
            }
        case .advance(let days):
            content.title = "\(item.emoji) \(item.title) 快到了"
            content.body = days == 1 ? "明天就是这个重要日期。" : "还有 \(days) 天，提前准备一下。"
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: repeats)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    private static func triggerDateComponents(for item: ImportantDate, kind: ReminderKind) -> DateComponents? {
        let cal = Calendar.current
        let daysOffset: Int
        switch kind {
        case .dayOf:
            daysOffset = 0
        case .advance(let days):
            daysOffset = -days
        }

        guard let fireDate = cal.date(byAdding: .day, value: daysOffset, to: item.date) else { return nil }
        let components: Set<Calendar.Component> = item.recurrenceRule == .yearly
            ? [.month, .day]
            : [.year, .month, .day]
        var comps = cal.dateComponents(components, from: fireDate)
        comps.hour = 9
        comps.minute = 0
        return comps
    }

    static func remove(_ item: ImportantDate) {
        let base = baseID(for: item)
        var ids = ["\(base)-day", "\(base)-advance"]
        for index in 0..<8 {
            ids.append("\(base)-day-\(index)")
            ids.append("\(base)-advance-\(index)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func monthlyOccurrence(inMonthContaining monthDate: Date, day: Int, calendar cal: Calendar) -> Date {
        let range = cal.range(of: .day, in: .month, for: monthDate)
        let maxDay = range?.count ?? day
        var comps = cal.dateComponents([.year, .month], from: monthDate)
        comps.day = min(day, maxDay)
        return cal.startOfDay(for: cal.date(from: comps) ?? monthDate)
    }

    private static func baseID(for item: ImportantDate) -> String {
        "\(prefix)\(item.persistentModelID)"
    }

    private enum ReminderKind {
        case dayOf
        case advance(days: Int)

        var identifier: String {
            switch self {
            case .dayOf: "day"
            case .advance: "advance"
            }
        }
    }
}
