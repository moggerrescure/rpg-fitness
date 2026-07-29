import Foundation
import Network
import Combine
import FirebaseAuth

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType? = nil

    private var monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.rpgfitness.network", qos: .background)

    private init() {
        startMonitoring()
    }

    var connectionTypeName: String {
        switch connectionType {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        default: return "Unknown"
        }
    }

    /// Re-reads the current network path and restarts monitoring so Retry can recover without relaunching.
    func retryConnectionCheck() {
        applyPath(monitor.currentPath)
        monitor.cancel()
        startMonitoring()
    }

    private func startMonitoring() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.applyPath(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func applyPath(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = (path.status == .satisfied)
        connectionType = path.availableInterfaces.first?.type

        if !wasConnected && path.status == .satisfied {
            if AuthManager.shared.currentUser == nil {
                Auth.auth().signInAnonymously { _, _ in }
            }
            FirebaseService.shared.fetchLeaderboards()
        }
    }
}
