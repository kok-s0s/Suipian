import Foundation

enum AppGroupDefaults {
    static let groupID = "group.com.kok-s0s.Suipian"

    static func make() -> UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) != nil else {
            return nil
        }
        return UserDefaults(suiteName: groupID)
    }
}
