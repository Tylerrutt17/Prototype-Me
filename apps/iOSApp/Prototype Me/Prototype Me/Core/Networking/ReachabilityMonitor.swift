import Foundation
import Network

/// Wraps `NWPathMonitor` to track network connectivity state.
/// SyncEngine and UI observe `isConnected` to gate sync and show offline banners.
final class ReachabilityMonitor: Sendable {

    // MARK: - State

    enum ConnectionType: Sendable {
        case wifi
        case cellular
        case wired
        case unknown
    }

    struct Status: Sendable {
        let isConnected: Bool
        let connectionType: ConnectionType
    }

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.prototypeme.reachability", qos: .utility)

    // Thread-safe status via lock
    private let lock = NSLock()
    private var _status = Status(isConnected: true, connectionType: .unknown)

    /// Callbacks invoked on connectivity change (dispatched to main queue).
    nonisolated(unsafe) private var observers: [(Status) -> Void] = []

    // MARK: - Public

    var status: Status {
        lock.lock()
        defer { lock.unlock() }
        return _status
    }

    var isConnected: Bool { status.isConnected }

    // MARK: - Lifecycle

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied
            let type: ConnectionType
            if path.usesInterfaceType(.wifi) {
                type = .wifi
            } else if path.usesInterfaceType(.cellular) {
                type = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                type = .wired
            } else {
                type = .unknown
            }
            let newStatus = Status(isConnected: connected, connectionType: type)

            self.lock.lock()
            self._status = newStatus
            let currentObservers = self.observers
            self.lock.unlock()

            DispatchQueue.main.async {
                for observer in currentObservers {
                    observer(newStatus)
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Register a callback for connectivity changes. Called on main queue.
    func observe(_ handler: @escaping (Status) -> Void) {
        lock.lock()
        observers.append(handler)
        lock.unlock()
    }
}
