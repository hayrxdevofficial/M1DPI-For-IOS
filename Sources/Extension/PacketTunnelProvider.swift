import NetworkExtension
import Foundation

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var proxy: HTTPProxyServer?
    private var config: DPIConfiguration!

    override func startTunnel(options: [String : NSObject]?,
                             completionHandler: @escaping (Error?) -> Void) {
        config = DPIConfiguration.load()
        SharedLog.append(tag: "TUNNEL", message: "Запуск. Доменов: \(config.domains.count), IP: \(config.ips.count)")

        let proxyPort: UInt16 = 8888

        // Настраиваем системный прокси на localhost — весь HTTP/HTTPS пойдёт через наш сервер.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.1"],
                                               subnetMasks: ["255.255.255.0"])
        settings.ipv4Settings?.includedRoutes = []
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])

        let proxy = NEProxySettings()
        proxy.httpEnabled = true
        proxy.httpServer = NEProxyServer(address: "127.0.0.1", port: Int(proxyPort))
        proxy.httpsEnabled = true
        proxy.httpsServer = NEProxyServer(address: "127.0.0.1", port: Int(proxyPort))
        proxy.matchDomains = [""]
        settings.proxySettings = proxy

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                SharedLog.append(tag: "TUNNEL", message: "settings error: \(error)")
                completionHandler(error)
                return
            }
            do {
                let srv = try HTTPProxyServer(port: proxyPort,
                                              config: self.config)
                try srv.start()
                self.proxy = srv
                SharedLog.append(tag: "TUNNEL", message: "Прокси запущен на 127.0.0.1:\(proxyPort)")
                completionHandler(nil)
            } catch {
                SharedLog.append(tag: "TUNNEL", message: "proxy start error: \(error)")
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        SharedLog.append(tag: "TUNNEL", message: "Остановка: \(reason.rawValue)")
        proxy?.stop()
        proxy = nil
        completionHandler()
    }
}
