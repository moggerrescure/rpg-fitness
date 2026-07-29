import Foundation
import Combine

@MainActor
final class VersionManager: ObservableObject {
    static let shared = VersionManager()

    @Published var updateRequirement: UpdateRequirement = .noUpdate
    @Published var hasDismissedSoftUpdate: Bool = false

    enum UpdateRequirement: Equatable {
        case hardUpdate
        case softUpdate
        case noUpdate
    }

    private init() {}

    func checkVersion() async {
        let rc = RemoteConfigManager.shared
        let minVersion = rc.minVersion
        let latestVersion = rc.latestVersion
        let force = rc.forceUpdateRequired

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        print("📱 App Version: \(currentVersion)")
        print("☁️ Min: \(minVersion), Latest: \(latestVersion), force=\(force)")

        #if DEBUG
        // Allow local debugging even if RC force flag is on; still honor version gates when set.
        #endif

        let newRequirement = evaluateRequirement(
            current: currentVersion,
            minimum: minVersion,
            latest: latestVersion,
            forceRequired: force
        )

        if newRequirement != self.updateRequirement {
            self.updateRequirement = newRequirement
        }
    }

    private func evaluateRequirement(
        current: String,
        minimum: String,
        latest: String,
        forceRequired: Bool
    ) -> UpdateRequirement {
        if forceRequired {
            return .hardUpdate
        }
        if !minimum.isEmpty && isVersion(current, lessThan: minimum) {
            return .hardUpdate
        }
        if !latest.isEmpty && isVersion(current, lessThan: latest) {
            return .softUpdate
        }
        return .noUpdate
    }

    private func isVersion(_ v1: String, lessThan v2: String) -> Bool {
        let v1Components = v1.split(separator: ".").compactMap { Int($0) }
        let v2Components = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(v1Components.count, v2Components.count)

        for i in 0..<maxCount {
            let c1 = i < v1Components.count ? v1Components[i] : 0
            let c2 = i < v2Components.count ? v2Components[i] : 0
            if c1 < c2 { return true }
            if c1 > c2 { return false }
        }
        return false
    }
}
