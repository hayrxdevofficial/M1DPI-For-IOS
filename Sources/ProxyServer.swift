import Foundation
import Network

class ProxyServer: ObservableObject {
    private var listener: NWListener?
    private let port: UInt16 = 8888
    private let queue = DispatchQueue(label: "proxy.listener")
    private var activeConnections: Set<ProxyConnection> = []

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        l.newConnectionHandler = { [weak self] conn in
            guard let self = self else { return }
            let pc = ProxyConnection(connection: conn)
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
    weak var server: ProxyServer?
    private let queue = DispatchQueue(label: "proxy.conn")
    private var remote: NWConnection?
    private var headerBuffer = Data()
    private var targetHost = ""
    private var targetPort: UInt16 = 443

    init(connection: NWConnection) {
        self.connection = connection
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
            if let error = error { print(error); self.cleanup(); return }
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
            let hp = target.split(separator: ":")
            targetHost = hp.first.map(String.init) ?? target
            if hp.count > 1 { targetPort = UInt16(hp[1]) ?? 443 }

            guard connectRemote() else { cleanup(); return }

            let ok = "HTTP/1.1 200 Connection Established\r\n\r\n"
            connection.send(content: ok.data(using: .utf8), completion: .contentProcessed { [weak self] _ in
                self?.pipeTunnel()
            })
        } else {
            cleanup()
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
            if let error = error { print(error); self.cleanup(); return }
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
        if TLSHelper.isTLSHello(bytes), let sni = TLSHelper.findSNI(bytes) {
            var points: [Int] = [1]
            points.append(sni.start + max(1, (sni.end - sni.start) / 2))
            points = Array(Set(points.filter { $0 > 0 && $0 < data.count })).sorted()

            let bounds = [0] + points + [data.count]
            let segments = (0..<(bounds.count - 1)).map { data.subdata(in: bounds[$0]..<bounds[$0 + 1]) }
            
            sendSegments(segments, to: remote, index: 0)
        } else {
            remote.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func sendSegments(_ segments: [Data], to conn: NWConnection, index: Int) {
        guard index < segments.count else { return }
        conn.send(content: segments[index], completion: .contentProcessed { [weak self] _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.005) {
                self?.sendSegments(segments, to: conn, index: index + 1)
            }
        })
    }

    private func readFromRemote() {
        remote?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let error = error { print(error); self.cleanup(); return }
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
    static func findSNI(_ p: [UInt8]) -> (host: String, start: Int, end: Int)? {
        var i = 43
        guard i < p.count else { return nil }
        i += 1 + Int(p[i])
        guard i + 2 <= p.count else { return nil }
        let csLen = Int(p[i]) << 8 | Int(p[i + 1])
        i += 2 + csLen
        guard i + 1 <= p.count else { return nil }
        i += 1 + Int(p[i])
        guard i + 2 <= p.count else { return nil }
        let extLen = Int(p[i]) << 8 | Int(p[i + 1])
        i += 2
        let extEnd = min(i + extLen, p.count)
        while i + 4 <= extEnd {
            let etype = Int(p[i]) << 8 | Int(p[i + 1])
            let elen = Int(p[i + 2]) << 8 | Int(p[i + 3])
            i += 4
            if etype == 0 {
                guard i + 5 <= p.count else { return nil }
                let nl = Int(p[i + 3]) << 8 | Int(p[i + 4])
                let s = i + 5
                let e = s + nl
                guard e <= p.count, nl > 0 else { return nil }
                let host = String(bytes: p[s..<e], encoding: .ascii)?.lowercased() ?? ""
                return (host, s, e)
            }
            i += elen
        }
        return nil
    }
}
