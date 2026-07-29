import Combine
import Foundation
import FirebaseRemoteConfig

@MainActor
final class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()

    /// FitRPG-prefixed keys (shared Firebase project — do not collide with food_/workout_/yoga_).
    enum Keys {
        static let minVersion = "fitrpg_min_version"
        static let latestVersion = "fitrpg_latest_version"
        static let updateRequired = "fitrpg_update_required"
        static let updateTitle = "fitrpg_update_title"
        static let updateMessage = "fitrpg_update_message"
        static let updateURL = "fitrpg_update_url"
        static let appStoreID = "fitrpg_ios_app_store_id"
        /// When true, Profile shows "Fill for Screenshots" (Release/TestFlight). CF also gates on this.
        static let screenshotFill = "fitrpg_screenshot_fill"
        // Legacy aliases (pre-fitrpg_ rename)
        static let legacyMin = "rpg_minimum_ios_version"
        static let legacyRec = "rpg_recommended_ios_version"
        static let legacyStoreID = "rpg_ios_app_store_id"
    }

    private let remoteConfig = RemoteConfig.remoteConfig()

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults([
            Keys.minVersion: NSString(string: ""),
            Keys.latestVersion: NSString(string: ""),
            Keys.updateRequired: NSNumber(value: false),
            Keys.updateTitle: NSString(string: "Update Available"),
            Keys.updateMessage: NSString(string: "A new version of FitRPG is available with improvements and fixes."),
            Keys.updateURL: NSString(string: ""),
            Keys.appStoreID: NSString(string: AppStoreConfig.bundledAppStoreID ?? ""),
            Keys.screenshotFill: NSNumber(value: false),
        ] as [String: NSObject])
    }

    func fetchCloudValues() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            if status == .successFetchedFromRemote || status == .successUsingPreFetchedData {
                print("RemoteConfig successfully fetched and activated.")
            }
        } catch {
            print("RemoteConfig fetch failed: \(error)")
        }
    }

    func getString(forKey key: String) -> String {
        remoteConfig.configValue(forKey: key).stringValue ?? ""
    }

    func getBool(forKey key: String) -> Bool {
        remoteConfig.configValue(forKey: key).boolValue
    }

    /// Hard gate version (empty = no hard gate).
    var minVersion: String {
        let v = getString(forKey: Keys.minVersion).trimmingCharacters(in: .whitespacesAndNewlines)
        if !v.isEmpty { return v }
        return getString(forKey: Keys.legacyMin).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Soft / recommended version (empty = no soft prompt).
    var latestVersion: String {
        let v = getString(forKey: Keys.latestVersion).trimmingCharacters(in: .whitespacesAndNewlines)
        if !v.isEmpty { return v }
        return getString(forKey: Keys.legacyRec).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Force-update override (bool). When true, treat as hard update regardless of version.
    var forceUpdateRequired: Bool {
        getBool(forKey: Keys.updateRequired)
    }

    var updateTitle: String {
        let t = getString(forKey: Keys.updateTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Update Available" : t
    }

    var updateMessage: String {
        let m = getString(forKey: Keys.updateMessage).trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty
            ? "A new version of FitRPG is available with improvements and fixes."
            : m
    }

    var updateURLString: String {
        getString(forKey: Keys.updateURL).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Release/TestFlight gate for screenshot wallet fill UI (CF still enforces server-side).
    var screenshotFillEnabled: Bool {
        getBool(forKey: Keys.screenshotFill)
    }
}
