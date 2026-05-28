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
}
