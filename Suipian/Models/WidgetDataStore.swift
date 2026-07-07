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
    let recurrenceRule: String
}

enum WidgetDataStore {
    static func rebuildFragmentWidgets(_ fragments: [Fragment]) {
        guard let defaults = AppGroupDefaults.make() else { return }
        let publicFragments = fragments
            .filter { !$0.isPrivate }
            .sorted { $0.date > $1.date }

        var latestChanged = false
        if let latest = publicFragments.first {
            latestChanged = updateLatestFragment(latest, defaults: defaults)
        } else {
            latestChanged = defaults.object(forKey: kLatestFragmentKey) != nil
            if latestChanged { defaults.removeObject(forKey: kLatestFragmentKey) }
        }

        let tagsChanged = updateTagFragments(publicFragments, defaults: defaults)
        if latestChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: "com.kok-s0s.Suipian.latestFragment")
        }
        if tagsChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: "com.kok-s0s.Suipian.tagFeed")
        }
    }

    @discardableResult
    private static func updateLatestFragment(_ fragment: Fragment, defaults: UserDefaults) -> Bool {
        let payload = WidgetFragmentData(
            content: fragment.content,
            date: fragment.date,
            locationName: fragment.locationName,
            tags: fragment.tags
        )
        guard let encoded = try? JSONEncoder().encode(payload) else { return false }
        guard defaults.data(forKey: kLatestFragmentKey) != encoded else { return false }
        defaults.set(encoded, forKey: kLatestFragmentKey)
        return true
    }

    @discardableResult
    private static func setDataIfChanged(_ data: Data, forKey key: String, defaults: UserDefaults) -> Bool {
        guard defaults.data(forKey: key) != data else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    @discardableResult
    private static func setStringArrayIfChanged(_ value: [String], forKey key: String, defaults: UserDefaults) -> Bool {
        let oldValue = defaults.stringArray(forKey: key) ?? []
        guard oldValue != value else { return false }
        defaults.set(value, forKey: key)
        return true
    }

    // Writes tag-grouped fragment data for the TagFeedWidget.
    // Called whenever the fragment list changes.
    @discardableResult
    static func updateTagFragments(_ fragments: [Fragment]) -> Bool {
        guard let defaults = AppGroupDefaults.make() else { return false }
        let changed = updateTagFragments(fragments, defaults: defaults)
        if changed {
            WidgetCenter.shared.reloadTimelines(ofKind: "com.kok-s0s.Suipian.tagFeed")
        }
        return changed
    }

    // Writes tag-grouped fragment data for the TagFeedWidget.
    // Called whenever the fragment list changes.
    @discardableResult
    private static func updateTagFragments(_ fragments: [Fragment], defaults: UserDefaults) -> Bool {
        let public_ = fragments.filter { !$0.isPrivate }
        var changed = false

        // All fragments (capped at 50 for storage size)
        let allPayloads = public_.prefix(50).map {
            WidgetFragmentData(content: $0.content, date: $0.date,
                               locationName: $0.locationName, tags: $0.tags)
        }
        if let data = try? JSONEncoder().encode(Array(allPayloads)) {
            changed = setDataIfChanged(data, forKey: "tagFragments_all", defaults: defaults) || changed
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
            changed = setDataIfChanged(data, forKey: "tagFragmentsMap", defaults: defaults) || changed
        }

        // Available tag list (for widget configuration hint)
        changed = setStringArrayIfChanged(Array(tagMap.keys.sorted()), forKey: "widgetAvailableTags", defaults: defaults) || changed
        return changed
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
                    recurrenceRule: $0.recurrenceRule.rawValue
                )
            }

        guard let defaults = AppGroupDefaults.make() else { return }
        if let encoded = try? JSONEncoder().encode(Array(payloads)),
           setDataIfChanged(encoded, forKey: kImportantDatesKey, defaults: defaults) {
            WidgetCenter.shared.reloadTimelines(ofKind: "com.kok-s0s.Suipian.importantDateCountdown")
        }
    }
}
