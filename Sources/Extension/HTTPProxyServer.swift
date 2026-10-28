import Foundation
import Network

final class HTTPProxyServer {
    private let port: UInt16
    private let config: DPIConfiguration
    private let filters: Filters
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "proxy.listener")

    // Держим активные соединения — иначе ProxyConnection умирает сразу
    var activeConnections: Set<ProxyConnection> = []

    init(port: UInt16, config: DPIConfiguration) throws {
        self.port = port
        self.config = config
        self.filters = Filters(config: config)
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        l.newConnectionHandler = { [weak self] conn in
            guard let self = self else { return }
            let pc = ProxyConnection(connection: conn,
                                     config: self.config,
                                     filters: self.filters)
            pc.server = self
            self.activeConnections.insert(pc)
            SharedLog.append(tag: "PROXY", message: "Новое соединение, всего: \(self.activeConnections.count)")
            pc.start()
        }
        l.start(queue: queue)
        self.listener = l
    }

    func remove(_ conn: ProxyConnection) {
        activeConnections.remove(conn)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for c in activeConnections { c.cancel() }
        activeConnections.removeAll()
    }
}
