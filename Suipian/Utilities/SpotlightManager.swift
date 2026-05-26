import CoreSpotlight
import UniformTypeIdentifiers

struct SpotlightManager {
    private static let domain = "com.suipian.fragments"

    static func index(_ fragment: Fragment) {
        let item = searchableItem(for: fragment)
        CSSearchableIndex.default().indexSearchableItems([item]) { _ in }
    }

    static func reindexAll(_ fragments: [Fragment]) {
        let items = fragments.map { searchableItem(for: $0) }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    static func remove(itemID: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemID]) { _ in }
    }

    static func itemID(for fragment: Fragment) -> String {
        "fragment-\(Int(fragment.date.timeIntervalSince1970))-\(abs(fragment.content.hashValue) % 100000)"
    }

    private static func searchableItem(for fragment: Fragment) -> CSSearchableItem {
        let attr = CSSearchableItemAttributeSet(contentType: .text)

        let title = fragment.content.isEmpty
            ? (fragment.tags.first.map { "#\($0)" } ?? "碎片")
            : String(fragment.content.prefix(80))
        attr.title = title

        let meta = [fragment.mood, fragment.locationName, fragment.storyName]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        attr.contentDescription = meta.isEmpty ? nil : meta
        attr.keywords = fragment.tags
        attr.timestamp = fragment.date

        let item = CSSearchableItem(
            uniqueIdentifier: itemID(for: fragment),
            domainIdentifier: domain,
            attributeSet: attr
        )
        item.expirationDate = .distantFuture
        return item
    }
}
