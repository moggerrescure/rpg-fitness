import Combine
import Foundation
import FirebaseRemoteConfig

@MainActor
final class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()
    
    private let remoteConfig = RemoteConfig.remoteConfig()
    
    private init() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600 // 1 hour for production, can be lower for debug
        remoteConfig.configSettings = settings
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
        return remoteConfig.configValue(forKey: key).stringValue ?? ""
    }
}
