import Foundation
import Network

final class HTTPProxyServer {
    private let port: UInt16
    private let config: DPIConfiguration
    private let filters: Filters
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "proxy.listener")

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
            ProxyConnection(connection: conn,
                            config: self.config,
                            filters: self.filters).start()
        }
        l.start(queue: queue)
        self.listener = l
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}
