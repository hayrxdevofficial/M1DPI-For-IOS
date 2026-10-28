import Foundation
import Network

final class ProxyConnection: Hashable {

    let connection: NWConnection
    private let config: DPIConfiguration
    private let filters: Filters
    private let queue = DispatchQueue(label: "proxy.conn")

    weak var server: HTTPProxyServer?
    private var remote: NWConnection?
    private var headerBuffer = Data()
    private var targetHost = ""
    private var targetPort: UInt16 = 443

    init(connection: NWConnection, config: DPIConfiguration, filters: Filters) {
        self.connection = connection
        self.config = config
        self.filters = filters
    }

    static func == (lhs: ProxyConnection, rhs: ProxyConnection) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.cleanup() }
            if case .cancelled = state { self?.cleanup() }
        }
        connection.start(queue: queue)
        readHeader()
    }

    // ... весь остальной код без изменений ...

    private func cleanup() {
        connection.cancel()
        remote?.cancel()
        remote = nil
        server?.remove(self)
    }

    /// Публичный cancel для stop() в HTTPProxyServer
    func cancel() {
        cleanup()
    }
}
