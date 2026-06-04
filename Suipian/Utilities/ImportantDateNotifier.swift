import UserNotifications
import Foundation
import SwiftData

enum ImportantDateNotifier {
    private static let prefix = "important-date-"

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
        remove(item)

        if item.advanceReminderDays > 0 {
            schedule(item, kind: .advance(days: item.advanceReminderDays))
        }
        schedule(item, kind: .dayOf)
    }

    private static func schedule(_ item: ImportantDate, kind: ReminderKind) {
        guard let triggerDate = triggerDateComponents(for: item, kind: kind) else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["importantDateID": "\(item.persistentModelID)", "reminderKind": kind.identifier]

        switch kind {
        case .dayOf:
            content.title = "\(item.emoji) 今天是 \(item.title)"
            if item.isRecurring, let years = item.yearsElapsed, years > 0 {
                content.body = "今天是第 \(years + 1) 年，打开碎片记录这个特别的日子。"
            } else {
                content.body = "打开碎片，记录这个特别的日子。"
            }
        case .advance(let days):
            content.title = "\(item.emoji) \(item.title) 快到了"
            content.body = days == 1 ? "明天就是这个重要日期。" : "还有 \(days) 天，提前准备一下。"
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: item.isRecurring)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "\(baseID(for: item))-\(kind.identifier)",
                                  content: content,
                                  trigger: trigger)
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
        var comps = cal.dateComponents(item.isRecurring ? [.month, .day] : [.year, .month, .day], from: fireDate)
        comps.hour = 9
        comps.minute = 0
        return comps
    }

    static func remove(_ item: ImportantDate) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "\(baseID(for: item))-day",
            "\(baseID(for: item))-advance",
        ])
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
