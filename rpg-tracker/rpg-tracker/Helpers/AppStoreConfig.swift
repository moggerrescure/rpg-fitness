import Foundation

enum AppStoreConfig {
    /// Numeric App Store ID from App Store Connect (Apple ID).
    static let bundledAppStoreID: String? = "6785639478"

    /// Remote Config key: set `rpg_ios_app_store_id` to override the bundled ID without an app update.
    static let remoteConfigKey = "rpg_ios_app_store_id"

    static func appStoreURL(remoteConfig: RemoteConfigManager = .shared) -> URL? {
        let remoteID = remoteConfig.getString(forKey: remoteConfigKey).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remoteID.isEmpty {
            return URL(string: "https://apps.apple.com/app/id\(remoteID)")
        }
        guard let bundledAppStoreID, !bundledAppStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(bundledAppStoreID)")
    }
}
