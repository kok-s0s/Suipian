import UserNotifications
import Foundation

enum ImportantDateNotifier {
    static func rescheduleAll(_ dates: [ImportantDate]) {
        let center = UNUserNotificationCenter.current()
        // Remove all important-date notifications first
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("important-date-") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
            for d in dates where d.notificationEnabled { schedule(d) }
        }
    }

    static func schedule(_ item: ImportantDate) {
        guard item.notificationEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let id = "important-date-\(item.persistentModelID)"

        let content = UNMutableNotificationContent()
        content.sound = .default

        // Build anniversary text if applicable
        if item.isRecurring, let years = item.yearsElapsed, years > 0 {
            content.title = "\(item.emoji) \(item.title)"
            content.body = "今天是第 \(years + 1) 年，去记录一条碎片纪念这一天吧。"
        } else {
            content.title = "\(item.emoji) 今天是 \(item.title)"
            content.body = "打开碎片，记录这个特别的日子。"
        }

        let cal = Calendar.current
        var triggerComps: DateComponents
        if item.isRecurring {
            // Fire every year on month+day at 9:00 AM
            var comps = cal.dateComponents([.month, .day], from: item.date)
            comps.hour = 9; comps.minute = 0
            triggerComps = comps
        } else {
            // One-shot: fire at 9:00 AM on the date
            var comps = cal.dateComponents([.year, .month, .day], from: item.date)
            comps.hour = 9; comps.minute = 0
            triggerComps = comps
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: item.isRecurring)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func remove(_ item: ImportantDate) {
        let id = "important-date-\(item.persistentModelID)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
