import Foundation

enum AppStoreConfig {
    /// Numeric App Store ID from App Store Connect (Apple ID).
    static let bundledAppStoreID: String? = "6785639478"

    /// Remote Config key: set `fitrpg_ios_app_store_id` (or legacy `rpg_ios_app_store_id`) to override.
    static let remoteConfigKey = RemoteConfigManager.Keys.appStoreID
    static let legacyRemoteConfigKey = RemoteConfigManager.Keys.legacyStoreID

    static func appStoreURL(remoteConfig: RemoteConfigManager = .shared) -> URL? {
        let remoteID = remoteConfig.getString(forKey: remoteConfigKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !remoteID.isEmpty {
            return URL(string: "https://apps.apple.com/app/id\(remoteID)")
        }
        let legacyID = remoteConfig.getString(forKey: legacyRemoteConfigKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !legacyID.isEmpty {
            return URL(string: "https://apps.apple.com/app/id\(legacyID)")
        }
        guard let bundledAppStoreID, !bundledAppStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(bundledAppStoreID)")
    }
}
