import Foundation
import SwiftData

@Model
final class Fragment {
    var content: String
    // PHAsset local identifiers — photos and videos, no pixel data stored
    var mediaIdentifiers: [String]
    var date: Date
    var tags: [String]
    var latitude: Double
    var longitude: Double
    var locationName: String

    var hasLocation: Bool { latitude != 0 || longitude != 0 }
    var hasMedia: Bool { !mediaIdentifiers.isEmpty }

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
        self.date = date
        self.tags = tags
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}
