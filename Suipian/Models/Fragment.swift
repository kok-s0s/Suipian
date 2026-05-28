import Foundation
import SwiftData

@Model
final class Fragment {
    var content: String = ""
    var mediaIdentifiers: [String] = []
    var photosData: [Data] = []
    var date: Date = Date()
    var tags: [String] = []
    var latitude: Double = 0
    var longitude: Double = 0
    var locationName: String = ""
    var coverIdentifier: String?
    var isPrivate: Bool = false
    var isPinned: Bool = false
    var audioFileNames: [String] = []
    var audioData: [Data] = []
    var mood: String = ""
    var storyName: String = ""
    var musicTitle: String = ""
    var musicArtist: String = ""
    var musicAlbum: String = ""
    var musicArtworkData: Data = Data()
    var musicStoreID: String = ""
    var linkURL: String = ""
    var linkTitle: String = ""
    var linkDescription: String = ""
    var linkImageURL: String = ""

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
