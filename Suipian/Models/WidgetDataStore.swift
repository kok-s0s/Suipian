import Foundation
import WidgetKit

private let kAppGroupID = "group.com.kok-s0s.Suipian"
private let kLatestFragmentKey = "latestFragment"
private let kImportantDatesKey = "importantDates"

// Mirrors WidgetFragmentData in SuipianWidget.swift — must stay in sync.
private struct WidgetFragmentData: Codable {
    let content: String
    let date: Date
    let locationName: String
    let tags: [String]
}

// Mirrors WidgetImportantDateData in ImportantDateCountdownWidget.swift.
private struct WidgetImportantDateData: Codable {
    let title: String
    let date: Date
    let emoji: String
    let category: String
    let isRecurring: Bool
    let daysUntil: Int
}

enum WidgetDataStore {
    static func update(with fragment: Fragment) {
        guard !fragment.isPrivate else { return }
        let payload = WidgetFragmentData(
            content: fragment.content,
            date: fragment.date,
            locationName: fragment.locationName,
            tags: fragment.tags
        )
        if let encoded = try? JSONEncoder().encode(payload) {
            UserDefaults(suiteName: kAppGroupID)?.set(encoded, forKey: kLatestFragmentKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        UserDefaults(suiteName: kAppGroupID)?.removeObject(forKey: kLatestFragmentKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Writes tag-grouped fragment data for the TagFeedWidget.
    // Called whenever the fragment list changes.
    static func updateTagFragments(_ fragments: [Fragment]) {
        guard let defaults = UserDefaults(suiteName: kAppGroupID) else { return }

        let public_ = fragments.filter { !$0.isPrivate }

        // All fragments (capped at 50 for storage size)
        let allPayloads = public_.prefix(50).map {
            WidgetFragmentData(content: $0.content, date: $0.date,
                               locationName: $0.locationName, tags: $0.tags)
        }
        if let data = try? JSONEncoder().encode(Array(allPayloads)) {
            defaults.set(data, forKey: "tagFragments_all")
        }

        // Per-tag map (max 20 fragments per tag)
        var tagMap: [String: [WidgetFragmentData]] = [:]
        for fragment in public_ {
            for tag in fragment.tags {
                var list = tagMap[tag, default: []]
                guard list.count < 20 else { continue }
                list.append(WidgetFragmentData(content: fragment.content, date: fragment.date,
                                               locationName: fragment.locationName, tags: fragment.tags))
                tagMap[tag] = list
            }
        }
        if let data = try? JSONEncoder().encode(tagMap) {
            defaults.set(data, forKey: "tagFragmentsMap")
        }

        // Available tag list (for widget configuration hint)
        defaults.set(Array(tagMap.keys.sorted()), forKey: "widgetAvailableTags")

        WidgetCenter.shared.reloadTimelines(ofKind: "com.kok-s0s.Suipian.tagFeed")
    }

    static func updateImportantDates(_ dates: [ImportantDate]) {
        let payloads = dates
            .filter { !$0.isPast }
            .sorted { $0.daysUntil < $1.daysUntil }
            .prefix(12)
            .map {
                WidgetImportantDateData(
                    title: $0.title,
                    date: $0.date,
                    emoji: $0.emoji,
                    category: $0.category,
                    isRecurring: $0.isRecurring,
                    daysUntil: $0.daysUntil
                )
            }

        if let encoded = try? JSONEncoder().encode(Array(payloads)) {
            UserDefaults(suiteName: kAppGroupID)?.set(encoded, forKey: kImportantDatesKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "com.kok-s0s.Suipian.importantDateCountdown")
    }
}
