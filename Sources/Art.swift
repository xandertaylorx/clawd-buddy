import Cocoa
import UniformTypeIdentifiers

// Renders the README visuals from the app's own sprite and UI drawing code (run: Clawd --art docs/)

let artW = 640
let artH = 200

func renderScene(_ w: Int, _ h: Int, _ draw: () -> Void) -> CGImage {
    let scale = 2
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w * scale, pixelsHigh: h * scale, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    draw()
    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage!
}

func writeGIF(_ frames: [(CGImage, Double)], to path: String) {
    guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "com.compuserve.gif" as CFString,
                                                     frames.count, nil) else { return }
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for (img, d) in frames {
        CGImageDestinationAddImage(dest, img, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: d]] as CFDictionary)
    }
    CGImageDestinationFinalize(dest)
}

func writeCG(_ img: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)) }
}

func backdrop(_ w: Int, _ h: Int, floor: CGFloat = 34) {
    NSGradient(colors: [rgb(0.99, 0.965, 0.93), rgb(0.97, 0.90, 0.84)])!
        .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 90)
    // a dock-ish floor
    let band = NSBezierPath(roundedRect: NSRect(x: 40, y: 8, width: CGFloat(w) - 80, height: floor - 14), xRadius: 14, yRadius: 14)
    NSColor(white: 1, alpha: 0.55).setFill()
    band.fill()
    NSColor(white: 0, alpha: 0.08).setStroke()
    band.lineWidth = 1
    band.stroke()
}

func sprite(_ p: Pose, x: CGFloat, y: CGFloat, unit: CGFloat = 6, shadow: Bool = true) {
    if shadow {
        NSColor(white: 0, alpha: 0.10).setFill()
        NSBezierPath(ovalIn: NSRect(x: x + 8, y: y - 3, width: CGFloat(canvasW) * unit - 16, height: 7)).fill()
    }
    NSGraphicsContext.current?.shouldAntialias = false
    drawClawd(p, unit: unit, origin: CGPoint(x: x, y: y))
    NSGraphicsContext.current?.shouldAntialias = true
}

func bubble(_ text: String, shown: Int? = nil, cx: CGFloat, bottom: CGFloat, width: Int = artW) {
    let v = BubbleView()
    v.text = text
    v.shown = shown ?? text.count
    let sz = v.fit()
    v.frame = NSRect(origin: .zero, size: sz)
    let x = min(max(cx - sz.width / 2, 8), CGFloat(width) - sz.width - 8)
    v.tailX = cx - x
    NSGraphicsContext.current?.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: x, yBy: bottom)
    t.concat()
    v.draw(v.bounds)
    NSGraphicsContext.current?.restoreGraphicsState()
}

func label(_ s: String, x: CGFloat, y: CGFloat, size: CGFloat = 11, color: NSColor = NSColor(white: 0.35, alpha: 1),
           centered: Bool = true, weight: NSFont.Weight = .medium) {
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: size, weight: weight), .foregroundColor: color]
    let sz = (s as NSString).size(withAttributes: a)
    (s as NSString).draw(at: NSPoint(x: centered ? x - sz.width / 2 : x, y: y), withAttributes: a)
}

// MARK: hero animation

func heroFrames() -> [(CGImage, Double)] {
    struct Seg {
        let d: Double
        let f: (Double, Double) -> (Pose, CGFloat, CGFloat, String?)   // (u 0...1, seconds in) -> pose, x, lift, text
    }
    let floorY: CGFloat = 34
    let segs: [Seg] = [
        Seg(d: 1.2) { u, t in (Pose(bob: Int(t / 0.5) % 2), 90, 0, "Hi! I'm Clawd.") },
        Seg(d: 2.6) { u, t in
            let s = Int(t / 0.16)
            return (Pose(eyeShift: 1, legs: s % 2 == 0 ? 1 : 2, bob: s % 2), 90 + CGFloat(u) * 330, 0, "✻ Pondering…")
        },
        Seg(d: 1.5) { u, t in (Pose(eyes: .happy, armR: Int(t / 0.18) % 2 == 0 ? 5 : 3), 420, 0, "Hey you!") },
        Seg(d: 0.7) { u, _ in
            var p = Pose()
            if u < 0.1 || u > 0.9 { p.squash = true } else { p.eyes = .happy; p.armL = 3; p.armR = 3 }
            return (p, 420 + CGFloat(u) * 30, CGFloat(4 * 55 * u * (1 - u)), "Wheee!")
        },
        Seg(d: 2.0) { u, t in
            let s = Int(t / 0.22)
            let even = s % 2 == 0
            return (Pose(eyes: .happy, armL: even ? 5 : 1, armR: even ? 1 : 5, legs: even ? 1 : 2, bob: s % 2),
                    450 + CGFloat(((s / 4) % 2 == 0 ? 1 : -1) * 6), 0, "♪ ♫ ♪")
        },
        Seg(d: 1.7) { u, t in
            (Pose(eyeShift: 1, eyeLift: 1, armR: 2), 450, 0, "I need more tokens.")
        },
        Seg(d: 2.6) { u, t in
            (Pose(eyes: .sleep, squash: true), 450, 0, ["z", "zZ", "zZz"][Int(t / 0.7) % 3])
        },
    ]
    var frames: [(CGImage, Double)] = []
    let fps = 10.0
    let total = segs.reduce(0) { $0 + $1.d }
    var t = 0.0
    while t < total {
        var acc = 0.0
        var cur = segs[0]
        var start = 0.0
        for s in segs { if t < acc + s.d { cur = s; start = acc; break }; acc += s.d }
        let local = t - start
        let (pose, x, lift, text) = cur.f(min(1, local / cur.d), local)
        let img = renderScene(artW, artH) {
            backdrop(artW, artH)
            sprite(pose, x: x, y: floorY + lift)
            if let text {
                let typed = text.count <= 3 ? text.count : min(text.count, Int(local * 28))
                bubble(text, shown: typed, cx: x + 45, bottom: floorY + 66 + max(lift, 0) + 10)
            }
        }
        frames.append((img, 1 / fps))
        t += 1 / fps
    }
    return frames
}

// MARK: timer animation

func timerFrames() -> [(CGImage, Double)] {
    var frames: [(CGImage, Double)] = []
    let w = 420, h = 200
    for sec in stride(from: 12, through: 0, by: -1) {
        for half in 0..<2 {
            let img = renderScene(w, h) {
                backdrop(w, h)
                let bar = Int((Double(sec) / 12 * 9).rounded(.up))
                let p = Pose(armL: half, timer: sec, timerBar: bar, timerSecs: true)
                sprite(p, x: 165, y: 34, unit: 6)
                label("focus timer", x: 210, y: 150, size: 12)
            }
            frames.append((img, 0.5))
        }
    }
    for k in 0..<10 {
        let img = renderScene(w, h) {
            backdrop(w, h)
            let s = k % 2
            sprite(Pose(eyes: .happy, armL: s == 0 ? 5 : 1, armR: s == 0 ? 1 : 5, legs: s + 1, bob: s), x: 165, y: 34)
            bubble("Focus session done!", cx: 210, bottom: 34 + 66 + 12, width: w)
        }
        frames.append((img, 0.18))
    }
    return frames
}

// MARK: Token Catch animation

struct SplitMix {
    var s: UInt64
    mutating func next() -> Double {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}

func gameFrames() -> [(CGImage, Double)] {
    var rng = SplitMix(s: 7)
    var frames: [(CGImage, Double)] = []
    var tokens: [(x: CGFloat, y: CGFloat, vy: CGFloat, kind: TokenKind)] = []
    var cx: CGFloat = 300
    var score = 0
    var flash = 0.0
    var good = true
    let dt = 0.1
    var spawn = 0.0
    let floorY: CGFloat = 34
    let view = TokenView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    for i in 0..<70 {
        let t = Double(i) * dt
        spawn -= dt
        if spawn <= 0 {
            spawn = 0.42
            let r = rng.next()
            let kind: TokenKind = r < 0.22 ? .bug : (r < 0.3 ? .gem : .coin)
            tokens.append((CGFloat(60 + rng.next() * 500), CGFloat(artH), CGFloat(150 + rng.next() * 60), kind))
        }
        // chase the nearest good token, ignore bugs
        if let target = tokens.filter({ $0.kind != .bug }).min(by: { abs($0.x - cx - 35) + $0.y * 0.2 < abs($1.x - cx - 35) + $1.y * 0.2 }) {
            cx += (target.x - 35 - cx) * 0.34
        }
        let rect = CGRect(x: cx + 14, y: floorY + 4, width: 62, height: 56)
        var keep: [(x: CGFloat, y: CGFloat, vy: CGFloat, kind: TokenKind)] = []
        for var tk in tokens {
            tk.y -= tk.vy * CGFloat(dt)
            if CGRect(x: tk.x, y: tk.y, width: 20, height: 20).intersects(rect) {
                switch tk.kind {
                case .coin: score += 1; good = true
                case .gem: score += 5; good = true
                case .bug: score = max(0, score - 2); good = false
                }
                flash = 0.3
            } else if tk.y > floorY - 20 {
                keep.append(tk)
            }
        }
        tokens = keep
        flash -= dt
        let img = renderScene(artW, artH) {
            backdrop(artW, artH)
            for tk in tokens {
                view.kind = tk.kind
                NSGraphicsContext.current?.saveGraphicsState()
                let tr = NSAffineTransform()
                tr.translateX(by: tk.x, yBy: tk.y)
                tr.concat()
                view.draw(view.bounds)
                NSGraphicsContext.current?.restoreGraphicsState()
            }
            var p = Pose()
            p.legs = Int(t / 0.1) % 2 + 1
            if flash > 0 { p.eyes = good ? .happy : .wide; if good { p.armL = 4; p.armR = 4 } }
            sprite(p, x: cx, y: floorY)
            bubble("Score \(score)   ·   \(max(0, 30 - Int(t * 0.43 * 10) / 10))s", cx: 320, bottom: CGFloat(artH - 44))
        }
        frames.append((img, dt))
    }
    return frames
}

// MARK: still images

func posesImage() -> CGImage {
    let items: [(String, Pose)] = [
        ("idle", Pose()), ("walking", Pose(legs: 1, bob: 1)), ("waving", Pose(eyes: .happy, armR: 5)),
        ("dancing", Pose(eyes: .happy, armL: 5, armR: 1, legs: 1, bob: 1)), ("sleeping", Pose(eyes: .sleep, squash: true)),
        ("surprised", Pose(eyes: .wide, armL: 4, armR: 4, legs: 1)), ("thinking", Pose(eyeShift: 1, eyeLift: 1, armR: 2)),
    ]
    let w = 640, h = 150
    return renderScene(w, h) {
        backdrop(w, h, floor: 0)
        let cell = CGFloat(w) / CGFloat(items.count)
        for (i, it) in items.enumerated() {
            let cx = cell * (CGFloat(i) + 0.5)
            sprite(it.1, x: cx - 33, y: 52, unit: 4.4, shadow: false)
            label(it.0, x: cx, y: 22, size: 11)
        }
    }
}

func hatsImage() -> CGImage {
    let items: [(String, Hat)] = [("party", .party), ("santa", .santa), ("wizard", .wizard), ("crown", .crown), ("pumpkin", .pumpkin)]
    let w = 640, h = 160
    return renderScene(w, h) {
        backdrop(w, h, floor: 0)
        let cell = CGFloat(w) / CGFloat(items.count)
        for (i, it) in items.enumerated() {
            let cx = cell * (CGFloat(i) + 0.5)
            sprite(Pose(hat: it.1), x: cx - 36, y: 50, unit: 4.8, shadow: false)
            label(it.0, x: cx, y: 20, size: 11)
        }
    }
}

func trayImage() -> CGImage {
    let w = artW, h = 210
    return renderScene(w, h) {
        backdrop(w, h)
        var p = Pose()
        p.eyes = .happy; p.armL = 4; p.armR = 4
        sprite(p, x: 275, y: 34)
        // the tray
        let tw: CGFloat = 7 * 54 + 6 * 6 + 16
        let ox = (CGFloat(w) - tw) / 2
        let bg = NSBezierPath(roundedRect: NSRect(x: ox, y: 124, width: tw, height: 70), xRadius: 14, yRadius: 14)
        NSColor(white: 1, alpha: 0.65).setFill()
        bg.fill()
        for (i, k) in Tile.allCases.enumerated() {
            let tv = TileView(kind: k, frame: NSRect(x: 0, y: 0, width: 54, height: 54))
            tv.hot = (k == .shrink)
            NSGraphicsContext.current?.saveGraphicsState()
            let tr = NSAffineTransform()
            tr.translateX(by: ox + 8 + CGFloat(i) * 60, yBy: 132)
            tr.concat()
            tv.draw(tv.bounds)
            NSGraphicsContext.current?.restoreGraphicsState()
        }
    }
}

func menubarImage() -> CGImage {
    let w = artW, h = 190
    return renderScene(w, h) {
        NSGradient(colors: [rgb(0.99, 0.965, 0.93), rgb(0.97, 0.90, 0.84)])!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 90)
        let rows: [(String, Pose, String)] = [
            ("docked, idle", Pose(), ""),
            ("docked, talking", Pose(eyes: .happy, armR: 5), " ✻ Pondering…"),
            ("docked, as a timer", Pose(timer: 24, timerBar: 6), " 24:10"),
        ]
        for (i, r) in rows.enumerated() {
            let y = CGFloat(h) - 50 - CGFloat(i) * 56
            let bar = NSBezierPath(roundedRect: NSRect(x: 30, y: y, width: CGFloat(w) - 60, height: 30), xRadius: 9, yRadius: 9)
            NSColor(white: 1, alpha: 0.78).setFill()
            bar.fill()
            NSColor(white: 0, alpha: 0.08).setStroke()
            bar.stroke()
            // notch
            let notch = NSBezierPath(roundedRect: NSRect(x: 235, y: y + 8, width: 116, height: 22), xRadius: 8, yRadius: 8)
            NSColor.black.setFill()
            notch.fill()
            // stand-in icons
            for k in 0..<4 {
                NSColor(white: 0.55, alpha: 0.5).setFill()
                NSBezierPath(roundedRect: NSRect(x: 366 + CGFloat(k) * 24, y: y + 9, width: 14, height: 12), xRadius: 3, yRadius: 3).fill()
            }
            let img = spriteImage(r.1, unit: 1.5)
            NSGraphicsContext.current?.shouldAntialias = false
            NSGraphicsContext.current?.imageInterpolation = .none
            img.draw(in: NSRect(x: 470, y: y + 6, width: 22.5, height: 18))
            NSGraphicsContext.current?.shouldAntialias = true
            if !r.2.isEmpty { label(r.2, x: 494, y: y + 8, size: 11, color: NSColor(white: 0.15, alpha: 1), centered: false) }
            label(r.0, x: 36, y: y + 9, size: 11, color: NSColor(white: 0.4, alpha: 1), centered: false)
        }
    }
}

func shelfImage() -> CGImage {
    let w = artW, h = 200
    return renderScene(w, h) {
        backdrop(w, h)
        sprite(Pose(eyes: .happy, armR: 3), x: 275, y: 34)
        let names = ["report.pdf", "photo.heic", "notes.txt"]
        let sw: CGFloat = CGFloat(names.count) * 66 + 16 + 26
        let bg = ShelfBackground(frame: NSRect(x: 0, y: 0, width: sw, height: 92))
        NSGraphicsContext.current?.saveGraphicsState()
        let tr = NSAffineTransform()
        tr.translateX(by: (CGFloat(w) - sw) / 2, yBy: 108)
        tr.concat()
        bg.draw(bg.bounds)
        let types: [UTType] = [.pdf, .heic, .plainText]
        for (i, n) in names.enumerated() {
            let icon = NSWorkspace.shared.icon(for: types[i])
            icon.draw(in: NSRect(x: 8 + CGFloat(i) * 66 + 12, y: 34, width: 40, height: 40))
            label(n, x: 8 + CGFloat(i) * 66 + 32, y: 14, size: 9, color: clawdInk)
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

func renderArt(into dir: String) {
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    writeGIF(heroFrames(), to: "\(dir)/hero.gif")
    writeGIF(timerFrames(), to: "\(dir)/timer.gif")
    writeGIF(gameFrames(), to: "\(dir)/game.gif")
    writeCG(posesImage(), to: "\(dir)/poses.png")
    writeCG(hatsImage(), to: "\(dir)/hats.png")
    writeCG(trayImage(), to: "\(dir)/tray.png")
    writeCG(shelfImage(), to: "\(dir)/shelf.png")
    writeCG(menubarImage(), to: "\(dir)/menubar.png")
}
