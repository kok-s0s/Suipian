import Foundation
import SwiftData

@Model
final class Fragment {
    var content: String
    var photosData: [Data]
    var date: Date
    var tags: [String]
    var latitude: Double
    var longitude: Double
    var locationName: String

    var hasLocation: Bool { latitude != 0 || longitude != 0 }

    init(
        content: String = "",
        photosData: [Data] = [],
        date: Date = Date(),
        tags: [String] = [],
        latitude: Double = 0,
        longitude: Double = 0,
        locationName: String = ""
    ) {
        self.content = content
        self.photosData = photosData
        self.date = date
        self.tags = tags
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}
