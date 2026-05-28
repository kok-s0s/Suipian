import Foundation
import WidgetKit

private let kAppGroupID = "group.com.kok-s0s.Suipian"
private let kLatestFragmentKey = "latestFragment"

// Mirrors WidgetFragmentData in SuipianWidget.swift — must stay in sync.
private struct WidgetFragmentData: Codable {
    let content: String
    let date: Date
    let locationName: String
    let tags: [String]
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
}
