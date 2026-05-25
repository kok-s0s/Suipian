import Foundation
import SwiftData

@Model
final class Fragment {
    var content: String
    // PHAsset local identifiers — photo & video references, no pixel data stored
    var mediaIdentifiers: [String]
    // Kept for schema compatibility with older stores; not used by the UI
    var photosData: [Data]
    var date: Date
    var tags: [String]
    var latitude: Double
    var longitude: Double
    var locationName: String
    // nil means use first item in mediaIdentifiers
    var coverIdentifier: String?

    var hasLocation: Bool { latitude != 0 || longitude != 0 }
    var hasMedia: Bool { !mediaIdentifiers.isEmpty }
    var coverMediaID: String? {
        if let id = coverIdentifier, mediaIdentifiers.contains(id) { return id }
        return mediaIdentifiers.first
    }

    init(
        content: String = "",
        mediaIdentifiers: [String] = [],
        date: Date = Date(),
        tags: [String] = [],
        latitude: Double = 0,
        longitude: Double = 0,
        locationName: String = ""
    ) {
        self.content = content
        self.mediaIdentifiers = mediaIdentifiers
        self.photosData = []
        self.date = date
        self.tags = tags
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}
