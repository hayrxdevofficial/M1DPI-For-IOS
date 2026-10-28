import Foundation
import NetworkExtension
import Combine

@MainActor
final class TunnelManager: ObservableObject {
    @Published var isConnected = false
    @Published var status: String = "Отключено"
    @Published var error: String?

    private var manager: NETunnelProviderManager?

    init() {
        Task { await load() }
    }

    func load() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let m = managers.first {
                self.manager = m
                self.isConnected = (m.connection.status == .connected)
                self.status = statusText(m.connection.status)
            } else {
                self.manager = try await makeManager()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func makeManager() async throws -> NETunnelProviderManager {
        let m = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.example.m1dpi.extension"
        proto.serverAddress = "127.0.0.1"
        proto.providerConfiguration = [:]
        m.protocolConfiguration = proto
        m.localizedDescription = "M1DPI"
        m.isEnabled = true
        try await m.saveToPreferences()
        try await m.loadFromPreferences()
        return m
    }

    func toggle() {
        guard let m = manager else {
            Task { await load(); toggle() }
            return
        }
        if m.connection.status == .connected {
            m.connection.stopVPNTunnel()
            isConnected = false
            status = "Отключено"
            error = nil
        } else {
            do {
                try m.connection.startVPNTunnel()
                isConnected = true
                status = "Подключение..."
                error = nil
            } catch {
                // Здесь и прилетает "permission denied" от бесплатного Apple ID
                self.error = describeVPNError(error)
                self.status = "Ошибка запуска"
                self.isConnected = false
                SharedLog.append(tag: "ERROR", message: "startVPNTunnel: \(error)")
            }
        }
    }

    private func describeVPNError(_ error: Error) -> String {
        let ns = error as NSError
        // NEVPNErrorDomain code 1 = configurationInvalid, 5 = connectionFailed
        if ns.domain == "NEVPNErrorDomain" {
            switch ns.code {
            case 1:
                return "VPN-конфигурация невалидна. Скорее всего, у вашего Apple ID нет entitlement 'Network Extension'."
            case 5:
                return "Не удалось установить VPN-туннель. Проверьте, что расширение M1DPI Extension подписано тем же Apple ID."
            default:
                break
            }
        }
        let msg = ns.localizedDescription.lowercased()
        if msg.contains("permission") || msg.contains("denied") || msg.contains("entitlement") {
            return """
            iOS отказал в запуске VPN. Причина — у бесплатного Apple ID нет разрешения \
            'Network Extension'. Это ограничение Apple: нужен платный Apple Developer \
            Program ($99/год). Код приложения при этом полностью рабочий.
            """
        }
        return error.localizedDescription
    }

    private func statusText(_ s: NEVPNStatus) -> String {
        switch s {
        case .connected: return "Подключено"
        case .connecting: return "Подключение..."
        case .disconnecting: return "Отключение..."
        case .disconnected: return "Отключено"
        case .invalid: return "Ошибка"
        case .reasserting: return "Переподключение..."
        @unknown default: return "?"
        }
    }
}
