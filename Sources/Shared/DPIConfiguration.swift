import Foundation

struct DPIConfiguration: Codable {
    var domains: [String]
    var ips: [String]
    var modeAll: Bool
    var quicMode: String
    var splitFirstByte: Bool
    var splitInSNI: Bool
    var delayMs: Int
    var fragmentUnknownSNI: Bool

    static let appGroup = "group.com.example.m1dpi"

    static let defaultDomains: [String] = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
        "youtube-nocookie.com", "youtubei.googleapis.com", "youtube.googleapis.com",
        "youtubeembeddedplayer.googleapis.com", "jnn-pa.googleapis.com",
        "youtube-ui.l.google.com", "wide-youtube.l.google.com",
        "yt-video-upload.l.google.com", "googlevideo.com", "ytimg.com",
        "i.ytimg.com", "i9.ytimg.com", "s.ytimg.com", "yt3.ggpht.com",
        "yt4.ggpht.com", "yt3.googleusercontent.com", "googleusercontent.com",
        "googleapis.com"
    ]

    static let defaultIPs: [String] = [
        "142.250.150.198", "142.251.1.136", "173.194.73.190", "74.125.131.138",
        "216.239.32.223", "74.125.205.103", "64.233.164.95", "142.251.1.105",
        "173.194.31.199", "74.125.12.73"
    ]

    static func `default`() -> DPIConfiguration {
        DPIConfiguration(
            domains: defaultDomains,
            ips: defaultIPs,
            modeAll: false,
            quicMode: "all",
            splitFirstByte: true,
            splitInSNI: true,
            delayMs: 5,
            fragmentUnknownSNI: true
        )
    }

    static func load() -> DPIConfiguration {
        guard let ud = UserDefaults(suiteName: appGroup),
              let data = ud.data(forKey: "dpiConfig"),
              let cfg = try? JSONDecoder().decode(DPIConfiguration.self, from: data)
        else { return .default() }
        return cfg
    }

    func save() {
        guard let ud = UserDefaults(suiteName: Self.appGroup),
              let data = try? JSONEncoder().encode(self) else { return }
        ud.set(data, forKey: "dpiConfig")
    }
}
