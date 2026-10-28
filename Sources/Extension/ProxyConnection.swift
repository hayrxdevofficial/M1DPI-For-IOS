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

    func cancel() {
        cleanup()
    }

    // MARK: - Чтение HTTP-заголовка от клиента

    private func readHeader() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                SharedLog.append(tag: "PROXY", message: "recv header err: \(error)")
                self.cleanup(); return
            }
            if let data = data { self.headerBuffer.append(data) }
            if let headerEnd = self.findHeaderEnd(self.headerBuffer) {
                let header = self.headerBuffer[..<headerEnd]
                self.parseHeader(Data(header))
                return
            }
            if isComplete {
                self.cleanup(); return
            }
            self.readHeader()
        }
    }

    private func findHeaderEnd(_ d: Data) -> Int? {
        let pattern: [UInt8] = [13, 10, 13, 10]
        return d.range(of: Data(pattern))?.upperBound
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

            let hit = config.modeAll || filters.domainHit(targetHost)
            SharedLog.append(tag: "PROXY",
                             message: "CONNECT \(targetHost):\(targetPort) hit=\(hit)")

            guard connectRemote() else { cleanup(); return }

            let ok = "HTTP/1.1 200 Connection Established\r\n\r\n"
            connection.send(content: ok.data(using: .utf8),
                            completion: .contentProcessed { [weak self] _ in
                self?.pipeTunnel(hit: hit)
            })
        } else {
            var host = target
            if let s = host.range(of: "://") { host = String(host[s.upperBound...]) }
            if let slash = host.firstIndex(of: "/") { host = String(host[..<slash]) }
            let hp = host.split(separator: ":")
            targetHost = hp.first.map(String.init) ?? host
            targetPort = hp.count > 1 ? (UInt16(hp[1]) ?? 80) : 80
            if !connectRemote() { cleanup(); return }
            let leftover = headerBuffer.subdata(in: data.count..<headerBuffer.count)
            if !leftover.isEmpty {
                remote?.send(content: leftover, completion: .contentProcessed { _ in })
            }
            let hit = config.modeAll || filters.domainHit(targetHost)
            pipeTunnel(hit: hit)
        }
    }

    // MARK: - Подключение к реальному серверу

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
            case .ready:
                ok = true; sem.signal()
            case .failed, .cancelled:
                if !ok { sem.signal() }
            default: break
            }
        }
        r.start(queue: queue)
        _ = sem.wait(timeout: .now() + 5)
        return ok
    }

    // MARK: - Двунаправленный пайп

    private func pipeTunnel(hit: Bool) {
        guard remote != nil else { return }
        readFromClient(hit: hit)
        readFromRemote()
    }

    private func readFromClient(hit: Bool) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                SharedLog.append(tag: "PROXY", message: "client recv: \(error)")
                self.cleanup(); return
            }
            if let data = data, !data.isEmpty {
                self.forwardToRemote(data, hit: hit)
            }
            if isComplete { self.cleanup(); return }
            self.readFromClient(hit: hit)
        }
    }

    private func forwardToRemote(_ data: Data, hit: Bool) {
        guard let remote = remote else { return }

        let bytes = [UInt8](data)
        if hit && TLSHelper.isTLSHello(bytes),
           let sni = TLSHelper.findSNI(bytes),
           config.splitInSNI || config.splitFirstByte {

            SharedLog.append(tag: "SPLIT", message: "TLS hello for \(sni.host) [\(data.count) b]")

            var points: [Int] = []
            if config.splitFirstByte { points.append(1) }
            if config.splitInSNI {
                points.append(sni.start + max(1, (sni.end - sni.start) / 2))
            }
            points = Array(Set(points.filter { $0 > 0 && $0 < data.count })).sorted()

            if points.isEmpty {
                remote.send(content: data, completion: .contentProcessed { _ in })
                return
            }

            let bounds = [0] + points + [data.count]
            let segments = (0..<(bounds.count - 1)).map {
                data.subdata(in: bounds[$0]..<bounds[$0 + 1])
            }
            sendSegments(segments, to: remote, index: 0)
        } else {
            remote.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    SharedLog.append(tag: "PROXY", message: "remote send: \(error)")
                    self?.cleanup()
                }
            })
        }
    }

    private func sendSegments(_ segments: [Data], to conn: NWConnection, index: Int) {
        guard index < segments.count else { return }
        let seg = segments[index]
        conn.send(content: seg, completion: .contentProcessed { [weak self] error in
            if let error = error {
                SharedLog.append(tag: "SPLIT", message: "seg \(index) err: \(error)")
                self?.cleanup(); return
            }
            let delay = Double(self?.config.delayMs ?? 5) / 1000.0
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self?.sendSegments(segments, to: conn, index: index + 1)
            }
        })
    }

    private func readFromRemote() {
        remote?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                SharedLog.append(tag: "PROXY", message: "remote recv: \(error)")
                self.cleanup(); return
            }
            if let data = data, !data.isEmpty {
                self.connection.send(content: data, completion: .contentProcessed { err in
                    if err != nil { self.cleanup() }
                })
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
}
