import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Активные домены (для справки)") {
                    Text("youtube.com")
                    Text("googlevideo.com")
                    Text("ytimg.com")
                }
            }
            .navigationTitle("Списки")
        }
    }
}
