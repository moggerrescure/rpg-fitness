import Foundation
import Network
import Combine
import FirebaseAuth

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType? = nil

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.rpgfitness.network", qos: .background)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = (path.status == .satisfied)
                self?.connectionType = path.availableInterfaces.first?.type

                if !wasConnected && path.status == .satisfied {
                    // Reconnected — re-authenticate and refresh data
                    if AuthManager.shared.currentUser == nil {
                        Auth.auth().signInAnonymously { _, _ in }
                    }
                    FirebaseService.shared.fetchLeaderboards()
                }
            }
        }
        monitor.start(queue: queue)
    }

    var connectionTypeName: String {
        switch connectionType {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        default: return "Unknown"
        }
    }
}
