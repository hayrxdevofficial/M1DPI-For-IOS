import SwiftUI

struct ContentView: View {
    @StateObject private var tunnel = TunnelManager()

    var body: some View {
        TabView {
            StatusView(tunnel: tunnel)
                .tabItem { Label("Статус", systemImage: "shield.lefthalf.filled") }
            ListsView()
                .tabItem { Label("Списки", systemImage: "list.bullet") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
            LogsView()
                .tabItem { Label("Логи", systemImage: "doc.text") }
        }
    }
}
