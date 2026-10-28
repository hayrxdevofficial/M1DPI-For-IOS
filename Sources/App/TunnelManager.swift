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
        } else {
            do {
                try m.connection.startVPNTunnel()
                isConnected = true
                status = "Подключение..."
            } catch {
                self.error = error.localizedDescription
            }
        }
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
