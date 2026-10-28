import SwiftUI

struct LogsView: View {
    @State private var entries: [LogEntry] = []
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            List(entries.reversed()) { e in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(e.tag)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                        Spacer()
                        Text(e.date, style: .time)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(e.message)
                        .font(.system(.footnote, design: .monospaced))
                }
            }
            .navigationTitle("Логи")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Очистить", role: .destructive) {
                        SharedLog.clear()
                        entries = []
                    }
                }
            }
            .onAppear {
                entries = SharedLog.load()
                timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                    Task { @MainActor in entries = SharedLog.load() }
                }
            }
            .onDisappear { timer?.invalidate() }
        }
    }
}
