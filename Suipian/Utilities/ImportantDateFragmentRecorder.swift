import Foundation
import SwiftData

enum ImportantDateFragmentRecorder {
    @MainActor
    static func recordTodayItems(_ dates: [ImportantDate], in context: ModelContext) {
        let todayItems = dates.filter { $0.notificationEnabled && $0.isToday }
        guard !todayItems.isEmpty else { return }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
        let descriptor = FetchDescriptor<Fragment>(
            predicate: #Predicate<Fragment> { fragment in
                fragment.date >= todayStart && fragment.date < tomorrow
            }
        )
        let todaysFragments = (try? context.fetch(descriptor)) ?? []
        var changed = false

        for item in todayItems where !hasExistingFragment(for: item, in: todaysFragments) {
            let fragment = Fragment(content: content(for: item), date: Date(), tags: ["重要日期", item.category])
            fragment.mood = item.emoji
            context.insert(fragment)
            changed = true
        }

        if changed {
            try? context.save()
            let allFragments = (try? context.fetch(FetchDescriptor<Fragment>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
            WidgetDataStore.rebuildFragmentWidgets(allFragments)
        }
    }

    private static func hasExistingFragment(for item: ImportantDate, in fragments: [Fragment]) -> Bool {
        fragments.contains { fragment in
            fragment.tags.contains("重要日期")
                && fragment.content.contains(item.title)
        }
    }

    private static func content(for item: ImportantDate) -> String {
        var lines: [String]
        if item.isRecurring, let years = item.yearsElapsed, years > 0 {
            lines = ["\(item.emoji) 今天是 \(item.title) 第 \(years + 1) 年。"]
        } else {
            lines = ["\(item.emoji) 今天是 \(item.title)。"]
        }
        if !item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(item.note)
        }
        return lines.joined(separator: "\n")
    }
}
