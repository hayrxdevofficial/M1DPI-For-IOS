import SwiftUI

struct ListsView: View {
    @State private var config = DPIConfiguration.load()
    @State private var newDomain = ""
    @State private var newIP = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Режим ALL (весь HTTPS)", isOn: $config.modeAll)
                        .onChange(of: config.modeAll) { _, _ in config.save() }
                } footer: {
                    Text("Если включено — списки игнорируются, обрабатывается весь HTTPS-трафик.")
                }

                Section("Домены (\(config.domains.count))") {
                    HStack {
                        TextField("example.com", text: $newDomain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        Button("+") {
                            let d = newDomain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !d.isEmpty, !config.domains.contains(d) else { return }
                            config.domains.append(d)
                            config.save()
                            newDomain = ""
                        }
                    }
                    ForEach(config.domains, id: \.self) { d in
                        Text(d).font(.system(.body, design: .monospaced))
                    }
                    .onDelete { idx in
                        config.domains.remove(atOffsets: idx)
                        config.save()
                    }
                }

                Section("IP (\(config.ips.count))") {
                    HStack {
                        TextField("1.2.3.4", text: $newIP)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.decimalPad)
                        Button("+") {
                            let ip = newIP.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !ip.isEmpty, !config.ips.contains(ip) else { return }
                            config.ips.append(ip)
                            config.save()
                            newIP = ""
                        }
                    }
                    ForEach(config.ips, id: \.self) { ip in
                        Text(ip).font(.system(.body, design: .monospaced))
                    }
                    .onDelete { idx in
                        config.ips.remove(atOffsets: idx)
                        config.save()
                    }
                }

                Section {
                    Button("Сбросить к значениям по умолчанию", role: .destructive) {
                        config = .default()
                        config.save()
                    }
                    Button("Загрузить список YouTube") {
                        config.domains = DPIConfiguration.defaultDomains
                        config.ips = DPIConfiguration.defaultIPs
                        config.save()
                    }
                }
            }
            .navigationTitle("Списки")
        }
    }
}
