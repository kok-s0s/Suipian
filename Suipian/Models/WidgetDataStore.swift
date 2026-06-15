import Foundation
import WidgetKit

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
}

enum WidgetDataStore {
    static func rebuildFragmentWidgets(_ fragments: [Fragment]) {
        let publicFragments = fragments
            .filter { !$0.isPrivate }
            .sorted { $0.date > $1.date }

        if let latest = publicFragments.first {
            updateLatestFragment(latest)
        } else {
            AppGroupDefaults.make()?.removeObject(forKey: kLatestFragmentKey)
        }

        updateTagFragments(publicFragments)
        WidgetCenter.shared.reloadTimelines(ofKind: "com.kok-s0s.Suipian.latestFragment")
    }

    private static func updateLatestFragment(_ fragment: Fragment) {
        let payload = WidgetFragmentData(
            content: fragment.content,
            date: fragment.date,
            locationName: fragment.locationName,
            tags: fragment.tags
        )
        if let encoded = try? JSONEncoder().encode(payload) {
            AppGroupDefaults.make()?.set(encoded, forKey: kLatestFragmentKey)
        }
    }

    // Writes tag-grouped fragment data for the TagFeedWidget.
    // Called whenever the fragment list changes.
    static func updateTagFragments(_ fragments: [Fragment]) {
        guard let defaults = AppGroupDefaults.make() else { return }

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
                    isRecurring: $0.isRecurring
                )
            }

        if let encoded = try? JSONEncoder().encode(Array(payloads)) {
            AppGroupDefaults.make()?.set(encoded, forKey: kImportantDatesKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "com.kok-s0s.Suipian.importantDateCountdown")
    }
}
