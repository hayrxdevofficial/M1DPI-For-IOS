import Foundation

struct LogEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let tag: String
    let message: String

    init(tag: String, message: String) {
        self.id = UUID()
        self.date = Date()
        self.tag = tag
        self.message = message
    }
}

enum SharedLog {
    static func append(tag: String, message: String) {
        guard let ud = UserDefaults(suiteName: DPIConfiguration.appGroup) else { return }
        var entries: [LogEntry] = []
        if let data = ud.data(forKey: "logs"),
           let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            entries = decoded
        }
        entries.append(LogEntry(tag: tag, message: message))
        if entries.count > 200 { entries.removeFirst(entries.count - 200) }
        if let data = try? JSONEncoder().encode(entries) {
            ud.set(data, forKey: "logs")
        }
    }

    static func load() -> [LogEntry] {
        guard let ud = UserDefaults(suiteName: DPIConfiguration.appGroup),
              let data = ud.data(forKey: "logs"),
              let entries = try? JSONDecoder().decode([LogEntry].self, from: data)
        else { return [] }
        return entries
    }

    static func clear() {
        UserDefaults(suiteName: DPIConfiguration.appGroup)?.removeObject(forKey: "logs")
    }
}
