import SwiftUI

struct ContentView: View {
    @StateObject private var server = ProxyServer()
    @State private var isRunning = false

    var body: some View {
        TabView {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: isRunning ? "checkmark.shield.fill" : "shield.slash")
                    .font(.system(size: 80))
                    .foregroundStyle(isRunning ? .green : .gray)
                
                Text(isRunning ? "Сервер запущен" : "Сервер остановлен")
                    .font(.title2)
                
                Text("127.0.0.1:8888")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Button {
                    if isRunning {
                        server.stop()
                        BackgroundManager.shared.stop()
                    } else {
                        do {
                            try server.start()
                            BackgroundManager.shared.start()
                        } catch {
                            print(error)
                        }
                    }
                    isRunning.toggle()
                } label: {
                    Text(isRunning ? "Остановить" : "Запустить сервер")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRunning ? Color.red : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .tabItem { Label("Статус", systemImage: "shield.lefthalf.filled") }

            TutorialView()
                .tabItem { Label("Инструкция", systemImage: "book.fill") }

            SettingsView()
                .tabItem { Label("Списки", systemImage: "list.bullet") }
        }
    }
}
