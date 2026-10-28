import SwiftUI

struct SettingsView: View {
    @ObservedObject var config = Config.shared
    @State private var newDomain = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Режим ALL (резать весь HTTPS)", isOn: $config.modeAll)
                        .onChange(of: config.modeAll) { _ in config.save() }
                } footer: {
                    Text("Если выключено, обход работает только для сайтов из списка ниже.")
                }

                Section("Добавить сайт") {
                    HStack {
                        TextField("example.com", text: $newDomain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button("Добавить") {
                            config.addDomain(newDomain)
                            newDomain = ""
                        }
                    }
                }

                Section("Список сайтов (\(config.domains.count))") {
                    ForEach(config.domains, id: \.self) { domain in
                        Text(domain).font(.system(.body, design: .monospaced))
                    }
                    .onDelete { config.removeDomain(at: $0) }
                }
                
                Section {
                    Button("Сбросить к списку YouTube", role: .destructive) {
                        config.domains = config.defaultDomains
                        config.ips = config.defaultIPs
                        config.save()
                    }
                }
            }
            .navigationTitle("Списки")
        }
    }
}
