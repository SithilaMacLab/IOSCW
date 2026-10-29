import Combine
import Network

final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline: Bool

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "pocketlens.network-monitor")

    init(initiallyOnline: Bool = true, monitorsSystem: Bool = true) {
        isOnline = initiallyOnline
        guard monitorsSystem else { return }
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    func setOnline(_ online: Bool) {
        isOnline = online
    }
}
