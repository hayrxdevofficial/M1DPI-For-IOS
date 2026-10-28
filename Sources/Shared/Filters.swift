import Foundation

struct Filters {
    let domains: Set<String>
    let ips: Set<String>

    init(config: DPIConfiguration) {
        var d = Set<String>()
        for s in config.domains {
            let t = s.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "*."))
            if !t.isEmpty { d.insert(t) }
        }
        var i = Set<String>()
        for s in config.ips {
            let t = s.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { i.insert(t) }
        }
        self.domains = d
        self.ips = i
    }

    func ipHit(_ ip: String) -> Bool { ips.contains(ip) }

    func domainHit(_ host: String) -> Bool {
        var h = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        while !h.isEmpty {
            if domains.contains(h) { return true }
            guard let dot = h.firstIndex(of: ".") else { break }
            h = String(h[h.index(after: dot)...])
        }
        return false
    }
}
