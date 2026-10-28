import SwiftUI

struct SettingsView: View {
    @State private var config = DPIConfiguration.load()

    var body: some View {
        NavigationStack {
            Form {
                Section("Фрагментация TLS") {
                    Toggle("Отдельный байт первым", isOn: $config.splitFirstByte)
                        .onChange(of: config.splitFirstByte) { _, _ in config.save() }
                    Toggle("Разрезать внутри SNI", isOn: $config.splitInSNI)
                        .onChange(of: config.splitInSNI) { _, _ in config.save() }
                    Toggle("Фрагментировать без SNI", isOn: $config.fragmentUnknownSNI)
                        .onChange(of: config.fragmentUnknownSNI) { _, _ in config.save() }
                    Stepper("Задержка: \(config.delayMs) мс",
                            value: $config.delayMs, in: 0...100, step: 1)
                        .onChange(of: config.delayMs) { _, _ in config.save() }
                }

                Section("QUIC") {
                    Picker("Режим", selection: $config.quicMode) {
                        Text("All (весь UDP/443)").tag("all")
                        Text("Только из списка").tag("list")
                        Text("Отключено").tag("off")
                    }
                    .onChange(of: config.quicMode) { _, _ in config.save() }
                } footer: {
                    Text("При использовании прокси браузеры и так не применяют QUIC. Настройка сохранена для совместимости.")
                }

                Section("О приложении") {
                    HStack { Text("Версия"); Spacer(); Text("1.0") }
                    HStack { Text("Bundle ID"); Spacer()
                        Text(Bundle.main.bundleIdentifier ?? "—")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
