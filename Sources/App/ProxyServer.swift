import Foundation
import Network

class ProxyServer: ObservableObject {
    private var listener: NWListener?
    private let port: UInt16 = 8888
    private let queue = DispatchQueue(label: "proxy.listener")
    private var activeConnections: Set<ProxyConnection> = []
    private let config = Config.shared

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        l.newConnectionHandler = { [weak self] conn in
            guard let self = self else { return }
            let pc = ProxyConnection(connection: conn, config: self.config)
            pc.server = self
            self.activeConnections.insert(pc)
            pc.start()
        }
        l.start(queue: queue)
        self.listener = l
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for c in activeConnections { c.cancel() }
        activeConnections.removeAll()
    }
    
    func remove(_ conn: ProxyConnection) {
        activeConnections.remove(conn)
    }
}

final class ProxyConnection: Hashable {
    let connection: NWConnection
    let config: Config
    weak var server: ProxyServer?
    private let queue = DispatchQueue(label: "proxy.conn")
    private var remote: NWConnection?
    private var headerBuffer = Data()
    private var targetHost = ""
    private var targetPort: UInt16 = 443
    private var shouldFragment = false
    private var isCONNECT = false

    init(connection: NWConnection, config: Config) {
        self.connection = connection
        self.config = config
    }
    
    static func == (lhs: ProxyConnection, rhs: ProxyConnection) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.cleanup() }
            if case .cancelled = state { self?.cleanup() }
        }
        connection.start(queue: queue)
        readHeader()
    }

    private func readHeader() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if error != nil { self.cleanup(); return }
            if let data = data { self.headerBuffer.append(data) }
            if let headerEnd = self.findHeaderEnd(self.headerBuffer) {
                let header = self.headerBuffer[..<headerEnd]
                self.parseHeader(Data(header))
                return
            }
            if isComplete { self.cleanup(); return }
            self.readHeader()
        }
    }

    private func findHeaderEnd(_ d: Data) -> Int? {
        return d.range(of: Data([13, 10, 13, 10]))?.upperBound
    }

    private func parseHeader(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { cleanup(); return }
        let lines = text.components(separatedBy: "\r\n")
        guard let first = lines.first else { cleanup(); return }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { cleanup(); return }

        let method = String(parts[0])
        let target = String(parts[1])

        if method == "CONNECT" {
            isCONNECT = true
            let hp = target.split(separator: ":")
            targetHost = hp.first.map(String.init) ?? target
            if hp.count > 1 { targetPort = UInt16(hp[1]) ?? 443 }

            shouldFragment = config.domainHit(targetHost)
            print("[M1DPI] CONNECT \(targetHost):\(targetPort) hit=\(shouldFragment)")

            guard connectRemote() else { cleanup(); return }

            let ok = "HTTP/1.1 200 Connection Established\r\n\r\n"
            connection.send(content: ok.data(using: .utf8), completion: .contentProcessed { [weak self] _ in
                self?.pipeTunnel()
            })
        } else {
            // ОБЫЧНЫЙ HTTP - форвардим как есть, без фрагментации
            isCONNECT = false
            var host = target
            if let s = host.range(of: "://") { host = String(host[s.upperBound...]) }
            if let slash = host.firstIndex(of: "/") { host = String(host[..<slash]) }
            let hp = host.split(separator: ":")
            targetHost = hp.first.map(String.init) ?? host
            targetPort = hp.count > 1 ? (UInt16(hp[1]) ?? 80) : 80
            
            print("[M1DPI] HTTP \(method) \(targetHost):\(targetPort)")
            
            guard connectRemote() else { cleanup(); return }
            
            // Форвардим исходный запрос (уже прочитанный)
            let leftover = headerBuffer.subdata(in: data.count..<headerBuffer.count)
            if !leftover.isEmpty {
                remote?.send(content: leftover, completion: .contentProcessed { _ in })
            }
            pipeTunnel()
        }
    }

    private func connectRemote() -> Bool {
        let params = NWParameters.tcp
        let host = NWEndpoint.Host(targetHost)
        guard let port = NWEndpoint.Port(rawValue: targetPort) else { return false }
        let r = NWConnection(host: host, port: port, using: params)
        remote = r

        let sem = DispatchSemaphore(value: 0)
        var ok = false
        r.stateUpdateHandler = { state in
            switch state {
            case .ready: ok = true; sem.signal()
            case .failed, .cancelled: if !ok { sem.signal() }
            default: break
            }
        }
        r.start(queue: queue)
        _ = sem.wait(timeout: .now() + 5)
        return ok
    }

    private func pipeTunnel() {
        guard remote != nil else { return }
        readFromClient()
        readFromRemote()
    }

    private func readFromClient() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if error != nil { self.cleanup(); return }
            if let data = data, !data.isEmpty {
                self.forwardToRemote(data)
            }
            if isComplete { self.cleanup(); return }
            self.readFromClient()
        }
    }

    private func forwardToRemote(_ data: Data) {
        guard let remote = remote else { return }

        let bytes = [UInt8](data)
        
        // Режем ТОЛЬКО TLS ClientHello и ТОЛЬКО если домен в списке
        if shouldFragment && isCONNECT && TLSHelper.isTLSHello(bytes) {
            // Режем на 2 части: 1 байт + остальное (безопаснее чем середина SNI)
            if data.count > 2 {
                let part1 = data.subdata(in: 0..<1)
                let part2 = data.subdata(in: 1..<data.count)
                
                remote.send(content: part1, completion: .contentProcessed { [weak self] _ in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
                        self?.remote?.send(content: part2, completion: .contentProcessed { _ in })
                    }
                })
                return
            }
        }
        
        remote.send(content: data, completion: .contentProcessed { _ in })
    }

    private func readFromRemote() {
        remote?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if error != nil { self.cleanup(); return }
            if let data = data, !data.isEmpty {
                self.connection.send(content: data, completion: .contentProcessed { _ in })
            }
            if isComplete { self.cleanup(); return }
            self.readFromRemote()
        }
    }

    private func cleanup() {
        connection.cancel()
        remote?.cancel()
        remote = nil
        server?.remove(self)
    }

    func cancel() { cleanup() }
}

enum TLSHelper {
    static func isTLSHello(_ p: [UInt8]) -> Bool {
        return p.count > 44 && p[0] == 0x16 && p[1] == 3 && p[5] == 1
    }
}
