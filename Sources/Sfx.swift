import Cocoa

/// Soft 8-bit blips, synthesised at runtime (square / noise waves) so there are no audio assets.
enum Sfx {
    enum Kind: CaseIterable {
        case speak, hop, land, dock, coin, gem, bug, flap, score, hit, fanfare, alert, click, pet, drop, whoosh, poof
    }

    /// (start Hz, end Hz, milliseconds). 0 = rest, negative = noise.
    static func notes(_ k: Kind) -> [(Double, Double, Int)] {
        switch k {
        case .speak: return [(700, 700, 35), (940, 940, 45)]
        case .hop: return [(300, 720, 120)]
        case .land: return [(190, 80, 90)]
        case .dock: return [(520, 300, 80), (300, 640, 130)]
        case .coin: return [(988, 988, 50), (1319, 1319, 120)]
        case .gem: return [(784, 784, 60), (988, 988, 60), (1175, 1175, 60), (1568, 1568, 150)]
        case .bug: return [(190, 120, 150), (0, 0, 25), (160, 100, 150)]
        case .flap: return [(420, 640, 70)]
        case .score: return [(880, 880, 60), (1175, 1175, 110)]
        case .hit: return [(-1, -1, 160), (160, 60, 220)]
        case .fanfare: return [(523, 523, 90), (659, 659, 90), (784, 784, 90), (1047, 1047, 280)]
        case .alert: return [(784, 784, 90), (988, 988, 90), (784, 784, 90), (1175, 1175, 220)]
        case .click: return [(900, 900, 25)]
        case .pet: return [(700, 900, 90), (900, 1100, 130)]
        case .drop: return [(800, 420, 70)]
        case .whoosh: return [(-1, -1, 120), (400, 900, 100)]
        case .poof: return [(-1, -1, 130)]
        }
    }

    static var cache: [Kind: Data] = [:]
    static var playing: [NSSound] = []
    static var enabled: Bool { UserDefaults.standard.object(forKey: "sounds") as? Bool ?? true }

    static func wav(_ k: Kind) -> Data {
        if let d = cache[k] { return d }
        let rate = 22050.0
        var samples: [Int16] = []
        var seed: UInt32 = 12345
        for (f0, f1, ms) in notes(k) {
            let n = Int(rate * Double(ms) / 1000)
            var phase = 0.0
            for i in 0..<n {
                let u = Double(i) / Double(max(1, n))
                var v = 0.0
                if f0 < 0 {
                    seed = seed &* 1664525 &+ 1013904223
                    v = Double((seed >> 16) & 0xFF) / 127.5 - 1
                } else if f0 > 0 {
                    phase += (f0 + (f1 - f0) * u) / rate
                    v = (phase - floor(phase)) < 0.5 ? 1 : -1
                }
                let env = min(1, Double(i) / (rate * 0.004)) * (1 - u * 0.85)
                samples.append(Int16(v * env * 0.26 * 32767))
            }
        }
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append("RIFF".data(using: .ascii)!)
        u32(UInt32(36 + samples.count * 2))
        d.append("WAVEfmt ".data(using: .ascii)!)
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!)
        u32(UInt32(samples.count * 2))
        for s in samples { u16(UInt16(bitPattern: s)) }
        cache[k] = d
        return d
    }

    static func play(_ k: Kind, volume: Float = 0.3) {
        guard enabled, let s = NSSound(data: wav(k)) else { return }
        s.volume = volume
        s.play()
        playing.append(s)
        if playing.count > 12 { playing.removeFirst(playing.count - 12) }
    }
}
