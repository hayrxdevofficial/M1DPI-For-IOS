import Foundation

enum TLSHelper {
    static func isTLSHello(_ p: [UInt8]) -> Bool {
        guard p.count > 43 else { return false }
        return p[0] == 0x16 && p[1] == 3 && p[5] == 1
    }

    static func findSNI(_ p: [UInt8]) -> (host: String, start: Int, end: Int)? {
        var i = 43
        guard i < p.count else { return nil }
        i += 1 + Int(p[i])
        guard i + 2 <= p.count else { return nil }
        let csLen = Int(p[i]) << 8 | Int(p[i + 1])
        i += 2 + csLen
        guard i + 1 <= p.count else { return nil }
        i += 1 + Int(p[i])
        guard i + 2 <= p.count else { return nil }
        let extLen = Int(p[i]) << 8 | Int(p[i + 1])
        i += 2
        let extEnd = min(i + extLen, p.count)
        while i + 4 <= extEnd {
            let etype = Int(p[i]) << 8 | Int(p[i + 1])
            let elen = Int(p[i + 2]) << 8 | Int(p[i + 3])
            i += 4
            if etype == 0 {
                guard i + 5 <= p.count else { return nil }
                let nl = Int(p[i + 3]) << 8 | Int(p[i + 4])
                let s = i + 5
                let e = s + nl
                guard e <= p.count, nl > 0 else { return nil }
                let host = String(bytes: p[s..<e], encoding: .ascii)?.lowercased() ?? ""
                return (host, s, e)
            }
            i += elen
        }
        return nil
    }
}
