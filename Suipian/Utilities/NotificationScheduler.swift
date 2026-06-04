import UserNotifications
import SwiftData

enum NotificationScheduler {
    static func schedule(hour: Int, minute: Int, fragments: [Fragment]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])

        let content = UNMutableNotificationContent()
        content.sound = .default
        let (title, body) = makeMessage(fragments: fragments)
        content.title = title
        content.body = body

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "daily-reminder",
                                         content: content,
                                         trigger: trigger))
    }

    private static func makeMessage(fragments: [Fragment]) -> (title: String, body: String) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // 1. 距上次记录 N 天
        if let lastDate = fragments.map(\.date).max() {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: lastDate), to: today).day ?? 0
            if days >= 2 {
                return ("已经 \(days) 天没记录了", "今天发生了什么？打开碎片，把它留下来。")
            }
        }

        // 2. 今年同天有历史碎片
        let todayComponents = cal.dateComponents([.month, .day], from: today)
        let thisYear = cal.component(.year, from: today)
        let historical = fragments.filter {
            let c = cal.dateComponents([.month, .day], from: $0.date)
            return c.month == todayComponents.month
                && c.day == todayComponents.day
                && cal.component(.year, from: $0.date) < thisYear
        }
        if !historical.isEmpty {
            let years = historical.compactMap { cal.component(.year, from: $0.date) }
            if let earliest = years.min() {
                return ("今天历史上", "\(earliest) 年的今天你留下了碎片，今天呢？")
            }
        }

        // 3. 本周没有记录
        let weekStart = cal.date(byAdding: .day, value: -6, to: today)!
        let thisWeekCount = fragments.filter { $0.date >= weekStart }.count
        if thisWeekCount == 0 {
            return ("本周还没有记录", "随手记一条，哪怕只有一句话。")
        }

        // 4. 默认轮换文案
        let defaults: [(String, String)] = [
            ("今天记录了吗？", "打开碎片，把今天的瞬间留下来。"),
            ("记录一个小细节", "不用完整，一句话、一张图，都是碎片。"),
            ("今天有什么触动你？", "打开碎片记下来，未来的你会感谢现在的你。"),
        ]
        let idx = cal.component(.day, from: today) % defaults.count
        return defaults[idx]
    }
}
