import Foundation

class Config: ObservableObject {
    static let shared = Config()
    
    @Published var domains: [String] = []
    @Published var ips: [String] = []
    @Published var modeAll: Bool = false // Режим "резать всё"
    
    private let defaults = UserDefaults.standard
    
    // Твой список по умолчанию
    let defaultDomains = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
        "youtube-nocookie.com", "youtubei.googleapis.com", "youtube.googleapis.com",
        "youtubeembeddedplayer.googleapis.com", "jnn-pa.googleapis.com",
        "youtube-ui.l.google.com", "wide-youtube.l.google.com",
        "yt-video-upload.l.google.com", "googlevideo.com", "ytimg.com",
        "i.ytimg.com", "i9.ytimg.com", "s.ytimg.com", "yt3.ggpht.com",
        "yt4.ggpht.com", "yt3.googleusercontent.com", "googleusercontent.com",
        "googleapis.com"
    ]
    let defaultIPs = [
        "142.250.150.198", "142.251.1.136", "173.194.73.190", "74.125.131.138",
        "216.239.32.223", "74.125.205.103", "64.233.164.95", "142.251.1.105",
        "173.194.31.199", "74.125.12.73"
    ]
    
    init() {
        if let saved = defaults.array(forKey: "domains") as? [String],
           let savedIPs = defaults.array(forKey: "ips") as? [String] {
            self.domains = saved
            self.ips = savedIPs
            self.modeAll = defaults.bool(forKey: "modeAll")
        } else {
            self.domains = defaultDomains
            self.ips = defaultIPs
            self.modeAll = false
            save()
        }
    }
    
    func save() {
        defaults.set(domains, forKey: "domains")
        defaults.set(ips, forKey: "ips")
        defaults.set(modeAll, forKey: "modeAll")
    }
    
    func addDomain(_ d: String) {
        let clean = d.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty && !domains.contains(clean) {
            domains.append(clean)
            save()
        }
    }
    
    func removeDomain(at offsets: IndexSet) {
        domains.remove(atOffsets: offsets)
        save()
    }
    
    func domainHit(_ host: String) -> Bool {
        if modeAll { return true }
        var h = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        while !h.isEmpty {
            if domains.contains(h) { return true }
            guard let dot = h.firstIndex(of: ".") else { break }
            h = String(h[h.index(after: dot)...])
        }
        return false
    }
}
