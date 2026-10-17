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
        for (i, k) in Tile.files.enumerated() {
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
    writeCG(ogImage(), to: "\(dir)/og.png")
    let of = organizeFrames()
    writeGIF(of, to: "\(dir)/organize.gif")
    if let dbg = ProcessInfo.processInfo.environment["CLAWD_ART_DEBUG"] { writeCG(of[min(40, of.count - 1)].0, to: "\(dbg)/mid.png"); writeCG(of[of.count - 1].0, to: "\(dbg)/end.png") }
    writeCG(linksImage(), to: "\(dir)/links.png")
    writeCG(accessoriesImage(), to: "\(dir)/accessories.png")
    writeGIF(flapFrames(), to: "\(dir)/flap.gif")
    writeCG(githubImage(), to: "\(dir)/github.png")
    writeCG(moodsImage(), to: "\(dir)/moods.png")
    let bk = basketballFrames()
    writeGIF(bk, to: "\(dir)/basketball.gif")
    if let dbg = ProcessInfo.processInfo.environment["CLAWD_ART_DEBUG"] { writeCG(bk[16].0, to: "\(dbg)/bk16.png"); writeCG(bk[30].0, to: "\(dbg)/bk30.png") }
    let bf = ballFrames()
    writeGIF(bf, to: "\(dir)/ball.gif")
    if let dbg = ProcessInfo.processInfo.environment["CLAWD_ART_DEBUG"] { writeCG(bf[12].0, to: "\(dbg)/ball12.png"); writeCG(bf[60].0, to: "\(dbg)/ball60.png") }
}

// MARK: organise + links visuals

func fileIconArt(_ ext: String, _ color: NSColor, at p: CGPoint) {
    let r = NSRect(x: p.x - 13, y: p.y - 16, width: 26, height: 32)
    let body = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
    NSColor.white.setFill()
    body.fill()
    color.setFill()
    NSBezierPath(roundedRect: NSRect(x: r.minX, y: r.maxY - 11, width: r.width, height: 11), xRadius: 4, yRadius: 4).fill()
    NSColor(white: 0, alpha: 0.18).setStroke()
    body.lineWidth = 1
    body.stroke()
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 7, weight: .bold), .foregroundColor: NSColor.white]
    let sz = (ext as NSString).size(withAttributes: a)
    (ext as NSString).draw(at: NSPoint(x: r.midX - sz.width / 2, y: r.maxY - 9.5), withAttributes: a)
}

func organizeFrames() -> [(CGImage, Double)] {
    let w = 640, h = 270
    let bins: [(String, String, NSColor)] = [("Images", "png", rgb(0.35, 0.6, 0.9)), ("Documents", "pdf", rgb(0.85, 0.35, 0.35)),
                                              ("Audio", "mp3", rgb(0.6, 0.4, 0.85)), ("Videos", "mov", rgb(0.95, 0.6, 0.2)),
                                              ("Screenshots", "png", rgb(0.2, 0.7, 0.65))]
    let order = [0, 1, 2, 0, 3, 4, 1, 0, 2, 4, 1, 0]   // which bin each of the 12 files goes to
    let bx0: CGFloat = 100, by: CGFloat = 130
    let clawdX: CGFloat = 275
    let flight = 0.55, spacing = 0.33
    let binViews = bins.map { b -> BinView in let v = BinView(frame: NSRect(x: 0, y: 0, width: 80, height: 62)); v.name = b.0; return v }
    var frames: [(CGImage, Double)] = []
    let dt = 0.08
    var t = 0.0
    let promptEnd = 2.0, start = 2.2, total = start + Double(order.count) * spacing + flight + 2.6
    while t < total {
        let tt = t - start
        let counts = bins.indices.map { bi in order.enumerated().filter { $0.element == bi && tt >= Double($0.offset) * spacing + flight }.count }
        let done = tt >= Double(order.count) * spacing + flight
        let img = renderScene(w, h) {
            backdrop(w, h)
            let s = Int(t / 0.1)
            var p = Pose(eyes: .happy)
            if t < promptEnd { p = Pose(bob: Int(t / 0.7) % 2) }
            else if done { p.armL = 5; p.armR = 5; p.bob = s % 2 }
            else { p.armL = s % 2 == 0 ? 5 : 1; p.armR = s % 2 == 0 ? 1 : 5; p.legs = s % 2 + 1; p.bob = s % 2 }
            sprite(p, x: clawdX, y: 34)
            if t < promptEnd {
                // the prompt after dropping Clawd on a Finder window
                let tw: CGFloat = 2 * 54 + 6 + 16
                let ox = clawdX + 45 - tw / 2
                for (i, k) in [Tile.organize, Tile.cancel].enumerated() {
                    let tv = TileView(kind: k, frame: NSRect(x: 0, y: 0, width: 54, height: 54))
                    tv.hot = (i == 0 && t > 1.5)
                    NSGraphicsContext.current?.saveGraphicsState()
                    let tr = NSAffineTransform()
                    tr.translateX(by: ox + 8 + CGFloat(i) * 60, yBy: 128)
                    tr.concat()
                    tv.draw(tv.bounds)
                    NSGraphicsContext.current?.restoreGraphicsState()
                }
                bubble("Downloads has 12 files I can sort. Organise it?", cx: clawdX + 45, bottom: 196)
                return
            }
            for (i, v) in binViews.enumerated() {
                v.count = counts[i]
                var bounce: CGFloat = 0
                for (k, bi) in order.enumerated() where bi == i {
                    let since = tt - (Double(k) * spacing + flight)
                    if since >= 0 && since < 0.5 { bounce = max(bounce, CGFloat(10 * pow(0.84, since * 12.5))) }
                }
                NSGraphicsContext.current?.saveGraphicsState()
                let tr = NSAffineTransform()
                tr.translateX(by: bx0 + CGFloat(i) * 90, yBy: by + bounce)
                tr.concat()
                v.draw(v.bounds)
                NSGraphicsContext.current?.restoreGraphicsState()
            }
            for (k, bi) in order.enumerated() {
                let u = (tt - Double(k) * spacing) / flight
                guard u >= 0, u < 1 else { continue }
                let from = CGPoint(x: clawdX + 80, y: 78)
                let to = CGPoint(x: bx0 + CGFloat(bi) * 90 + 40, y: by + 34)
                let px = from.x + (to.x - from.x) * CGFloat(u)
                let py = from.y + (to.y - from.y) * CGFloat(u) + 70 * CGFloat(4 * u * (1 - u))
                fileIconArt(bins[bi].1, bins[bi].2, at: CGPoint(x: px, y: py))
            }
            let n = counts.reduce(0, +)
            bubble(done ? "Sorted 12 files into 5 folders ✨  Undo is in my menu." : "Sorting Downloads…  \(n)/12",
                   cx: 320, bottom: 202)
        }
        frames.append((img, t >= promptEnd - 0.2 && t < promptEnd ? 0.08 : dt))
        t += dt
    }
    return frames
}

func linksImage() -> CGImage {
    let w = artW, h = 220
    return renderScene(w, h) {
        backdrop(w, h)
        sprite(Pose(eyes: .happy, armL: 4, armR: 4), x: 275, y: 34)
        // the tray: MP3 / MP4
        let tw: CGFloat = 2 * 54 + 6 + 16
        let ox = 275 + 45 - tw / 2
        let bg = NSBezierPath(roundedRect: NSRect(x: ox, y: 130, width: tw, height: 70), xRadius: 14, yRadius: 14)
        NSColor(white: 1, alpha: 0.65).setFill()
        bg.fill()
        for (i, k) in [Tile.mp3, Tile.mp4].enumerated() {
            let tv = TileView(kind: k, frame: NSRect(x: 0, y: 0, width: 54, height: 54))
            tv.hot = (i == 0)
            NSGraphicsContext.current?.saveGraphicsState()
            let tr = NSAffineTransform()
            tr.translateX(by: ox + 8 + CGFloat(i) * 60, yBy: 138)
            tr.concat()
            tv.draw(tv.bounds)
            NSGraphicsContext.current?.restoreGraphicsState()
        }
        // a link chip being dragged in
        for (k, text) in ["youtube.com/watch?v=…", "open.spotify.com/track/…"].enumerated() {
            let a: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium), .foregroundColor: clawdInk]
            let sz = (text as NSString).size(withAttributes: a)
            let r = NSRect(x: k == 0 ? 40 : 360, y: k == 0 ? 160 : 100, width: sz.width + 22, height: 24)
            let chip = NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12)
            bubbleCream.setFill()
            chip.fill()
            clawdOrange.setStroke()
            chip.lineWidth = 1.5
            chip.stroke()
            (text as NSString).draw(at: NSPoint(x: r.minX + 11, y: r.minY + 6), withAttributes: a)
        }
    }
}

// MARK: v1.4 visuals: accessories, flappy, github panel, moods

func accessoriesImage() -> CGImage {
    let items: [(String, Pose)] = [
        ("rain", Pose(eyes: .happy, weather: .rain, twinkle: 1)), ("snow", Pose(weather: .snow, twinkle: 2)),
        ("hot", Pose(weather: .hot)), ("cold", Pose(weather: .cold)),
        ("night", Pose(eyes: .sleep, hat: .nightcap, night: true, twinkle: 1)),
    ]
    let w = 640, h = 170
    return renderScene(w, h) {
        backdrop(w, h, floor: 0)
        let cell = CGFloat(w) / CGFloat(items.count)
        for (i, it) in items.enumerated() {
            let cx = cell * (CGFloat(i) + 0.5)
            sprite(it.1, x: cx - 36, y: 52, unit: 4.8, shadow: false)
            label(it.0, x: cx, y: 20, size: 11)
        }
    }
}

func flapFrames() -> [(CGImage, Double)] {
    let w = 640, h = 250
    let floorY: CGFloat = 34
    let gaps: [CGFloat] = [140, 95, 165, 110, 150]
    let speed: CGFloat = 190, spacing: CGFloat = 250, gap: CGFloat = 130
    let clawdX: CGFloat = 120
    let pv = PipeView(frame: .zero)
    var frames: [(CGImage, Double)] = []
    var cy: CGFloat = 120
    let dt = 0.07
    for i in 0..<86 {
        let t = Double(i) * dt
        let off = speed * CGFloat(t)
        let xs = gaps.indices.map { 700 + CGFloat($0) * spacing - off }
        // aim for the gap of the next pipe still ahead
        let next = gaps.indices.first(where: { xs[$0] + 72 > clawdX + 10 }) ?? 0
        let target = gaps[next] - 40 + 14 * CGFloat(sin(t * 9))
        cy += (target - cy) * 0.16
        let score = xs.filter { $0 + 72 < clawdX }.count
        let img = renderScene(w, h) {
            backdrop(w, h)
            for (k, gx) in xs.enumerated() where gx > -80 && gx < CGFloat(w) + 10 {
                let gc = floorY + gaps[k]
                pv.capAtBottom = true
                var topH = CGFloat(h) - (gc + gap / 2)
                if topH > 0 {
                    pv.frame = NSRect(x: 0, y: 0, width: 72, height: topH)
                    NSGraphicsContext.current?.saveGraphicsState()
                    let tr = NSAffineTransform(); tr.translateX(by: gx, yBy: gc + gap / 2); tr.concat()
                    pv.draw(pv.bounds)
                    NSGraphicsContext.current?.restoreGraphicsState()
                }
                pv.capAtBottom = false
                topH = gc - gap / 2 - floorY
                if topH > 0 {
                    pv.frame = NSRect(x: 0, y: 0, width: 72, height: topH)
                    NSGraphicsContext.current?.saveGraphicsState()
                    let tr = NSAffineTransform(); tr.translateX(by: gx, yBy: floorY); tr.concat()
                    pv.draw(pv.bounds)
                    NSGraphicsContext.current?.restoreGraphicsState()
                }
            }
            let flapping = Int(t / 0.18) % 2 == 0
            let p = Pose(eyes: .wide, armL: flapping ? 5 : 1, armR: flapping ? 5 : 1, legs: 1)
            sprite(p, x: clawdX - 45 + 20, y: floorY + cy - 30, shadow: false)
            bubble("Score \(score)", cx: 320, bottom: CGFloat(h) - 50)
        }
        frames.append((img, dt))
    }
    return frames
}

func githubImage() -> CGImage {
    let now = Date()
    let data = GHData(login: "you", repos: [
        GHRepo(name: "clawd-buddy", nwo: "you/clawd-buddy", url: "", stars: 12, isPrivate: false, pushed: now.addingTimeInterval(-3600), prs: 2, ci: .ok),
        GHRepo(name: "side-project", nwo: "you/side-project", url: "", stars: 3, isPrivate: true, pushed: now.addingTimeInterval(-86400), prs: 0, ci: .fail),
        GHRepo(name: "dotfiles", nwo: "you/dotfiles", url: "", stars: 1, isPrivate: false, pushed: now.addingTimeInterval(-5 * 86400), prs: 0, ci: .none),
        GHRepo(name: "website", nwo: "you/website", url: "", stars: 7, isPrivate: false, pushed: now.addingTimeInterval(-600), prs: 1, ci: .running),
    ], reviews: [GHReview(title: "Fix flaky login test", repo: "team/api", url: "")], at: now)
    let list = RepoListView(frame: NSRect(x: 0, y: 0, width: RepoListView.width, height: RepoListView.height(data)))
    list.data = data
    let w = 640, h = Int(RepoListView.height(data)) + 110
    return renderScene(w, h) {
        backdrop(w, h)
        sprite(Pose(eyes: .happy, armR: 3), x: 275, y: 34)
        NSGraphicsContext.current?.saveGraphicsState()
        let tr = NSAffineTransform(); tr.translateX(by: (CGFloat(w) - RepoListView.width) / 2, yBy: 106); tr.concat()
        list.draw(list.bounds)
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

func moodsImage() -> CGImage {
    let w = 640, h = 230
    return renderScene(w, h) {
        backdrop(w, h)
        // left: a fort on a window's top edge
        let win = NSBezierPath(roundedRect: NSRect(x: 40, y: -20, width: 300, height: 150), xRadius: 10, yRadius: 10)
        NSColor(white: 1, alpha: 0.85).setFill()
        win.fill()
        NSColor(white: 0, alpha: 0.12).setStroke()
        win.stroke()
        for (i, c) in [rgb(0.95, 0.4, 0.35), rgb(0.97, 0.75, 0.25), rgb(0.4, 0.8, 0.4)].enumerated() {
            c.setFill()
            NSBezierPath(ovalIn: NSRect(x: 54 + CGFloat(i) * 16, y: 112, width: 10, height: 10)).fill()
        }
        let top: CGFloat = 130
        sprite(Pose(eyes: .happy, squash: true), x: 145, y: top)
        let brick = BrickView(frame: NSRect(x: 0, y: 0, width: 20, height: 14))
        for side in [-1, 1] {
            let outer = 145 + 45 + CGFloat(side) * 64
            for row in 0..<3 { for col in 0..<2 {
                NSGraphicsContext.current?.saveGraphicsState()
                let tr = NSAffineTransform(); tr.translateX(by: outer + CGFloat(side) * CGFloat(col) * 22 - 10, yBy: top + CGFloat(row) * 14); tr.concat()
                brick.draw(brick.bounds)
                NSGraphicsContext.current?.restoreGraphicsState()
            } }
        }
        bubble("Fort complete. 🏰", cx: 190, bottom: 186)
        label("builds a fort on a window", x: 190, y: 8, size: 10)
        // right: peeking over the bottom edge of the screen
        let bg = NSBezierPath(roundedRect: NSRect(x: 380, y: 14, width: 220, height: 200), xRadius: 12, yRadius: 12)
        NSColor(white: 1, alpha: 0.5).setFill()
        bg.fill()
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 380, y: 14, width: 220, height: 200)).addClip()
        sprite(Pose(eyeShift: -1), x: 445, y: -2, unit: 6, shadow: false)
        NSGraphicsContext.current?.restoreGraphicsState()
        label("peek-a-boo", x: 490, y: 190, size: 10)
        label("(+ sneezes and ghost mode)", x: 490, y: 174, size: 10)
    }
}

// MARK: physics ball visual (same constants as the live physics)

func ballFrames() -> [(CGImage, Double)] {
    let w = 640, h = 280
    let R = BallState.radius
    let floor: CGFloat = 34
    let platform = CGRect(x: 330, y: 0, width: 170, height: 118)   // a window whose top edge is at y = 118
    var pos = CGPoint(x: 90, y: 190), vel = CGPoint(x: 330, y: 260)
    var angle = 0.0, spin = -2.5
    var squash = 0, squashT = 0.0
    var trail: [CGPoint] = []
    var frames: [(CGImage, Double)] = []
    let simDt = 1.0 / 180
    var accum = 0.0
    for frame in 0..<110 {
        for _ in 0..<Int(0.055 / simDt) {
            let prevY = pos.y
            vel.y -= 1900 * CGFloat(simDt)
            pos.x += vel.x * CGFloat(simDt); pos.y += vel.y * CGFloat(simDt)
            var onSurface = false
            func hitY(_ top: CGFloat) {
                pos.y = top + R
                if vel.y < 0 {
                    if -vel.y > 220 { squash = 1; squashT = 0.13 }
                    vel.y = -vel.y > 130 ? -vel.y * 0.72 : 0
                }
                onSurface = true
            }
            if pos.y < floor + R { hitY(floor) }
            if vel.y <= 0, prevY - R >= platform.maxY - 2, pos.y - R < platform.maxY, pos.x > platform.minX - 8, pos.x < platform.maxX + 8 { hitY(platform.maxY) }
            if pos.x < R { pos.x = R; if vel.x < 0 { vel.x = -vel.x * 0.75; squash = 2; squashT = 0.13 } }
            if pos.x > CGFloat(w) - R { pos.x = CGFloat(w) - R; if vel.x > 0 { vel.x = -vel.x * 0.75; squash = 2; squashT = 0.13 } }
            if onSurface && abs(vel.y) < 8 {
                vel.x *= CGFloat(exp(-0.35 * simDt)); angle -= Double(vel.x / R) * simDt; spin = Double(-vel.x / R)
            } else { angle += spin * simDt }
            squashT -= simDt
            accum += simDt
        }
        if frame % 2 == 0 { trail.append(pos); if trail.count > 9 { trail.removeFirst() } }
        let step = ((Int((angle / (.pi / 16)).rounded()) % 32) + 32) % 32
        let img = renderScene(w, h) {
            backdrop(w, h)
            // a window to bounce on
            let win = NSBezierPath(roundedRect: NSRect(x: platform.minX, y: -20, width: platform.width, height: platform.maxY + 20), xRadius: 8, yRadius: 8)
            NSColor(white: 1, alpha: 0.8).setFill(); win.fill()
            NSColor(white: 0, alpha: 0.12).setStroke(); win.stroke()
            for (i, c) in [rgb(0.95, 0.4, 0.35), rgb(0.97, 0.75, 0.25), rgb(0.4, 0.8, 0.4)].enumerated() {
                c.setFill(); NSBezierPath(ovalIn: NSRect(x: platform.minX + 12 + CGFloat(i) * 15, y: platform.maxY - 20, width: 9, height: 9)).fill()
            }
            for (i, t) in trail.enumerated() {
                NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 0.07 + 0.03 * CGFloat(i)).setFill()
                NSBezierPath(ovalIn: NSRect(x: t.x - 6, y: t.y - 6, width: 12, height: 12)).fill()
            }
            var p = Pose(); p.ball = true; p.ballStep = step; p.ballSquash = squashT > 0 ? squash : 0
            let u: CGFloat = 6
            sprite(p, x: pos.x - 7.5 * u, y: pos.y - 7 * u, unit: u, shadow: false)
            if frame < 14 { label("throw me ➜", x: 140, y: 236, size: 12, color: NSColor(white: 0.35, alpha: 1)) }
        }
        frames.append((img, 0.055))
    }
    return frames
}

// MARK: basketball visual

func basketballFrames() -> [(CGImage, Double)] {
    let w = 640, h = 345
    let R = BallState.radius
    let floor: CGFloat = 34
    let rimY: CGFloat = 190
    let hoopX = CGFloat(w) - HoopView.size.width
    let front = hoopX + 11, back = hoopX + HoopView.size.width - 18
    let t = 0.75
    var pos = CGPoint(x: 90, y: floor + R)
    let target = CGPoint(x: (front + back) / 2, y: rimY)
    var vel = CGPoint(x: (target.x - pos.x) / CGFloat(t), y: (target.y - pos.y + 0.5 * 1900 * CGFloat(t * t)) / CGFloat(t))
    var angle = 0.0, spin = -2.0
    var scored = false, sway: CGFloat = 0, scoreFrame = -1
    let hv = HoopView(frame: NSRect(origin: .zero, size: HoopView.size))
    var frames: [(CGImage, Double)] = []
    let simDt = 1.0 / 180
    var squash = 0, squashT = 0.0
    var trail: [CGPoint] = []
    for frame in 0..<96 {
        let held = frame < 8     // sitting there, then thrown
        if !held {
            for _ in 0..<Int(0.055 / simDt) {
                let prevY = pos.y
                vel.y -= 1900 * CGFloat(simDt)
                pos.x += vel.x * CGFloat(simDt); pos.y += vel.y * CGFloat(simDt)
                if !scored, prevY > rimY, pos.y <= rimY, pos.x > front - 100, pos.x < back + 4 {
                    scored = true; scoreFrame = frame; vel.x *= 0.4; vel.y *= 0.55; sway = 1
                }
                var onSurface = false
                if pos.y < floor + R {
                    pos.y = floor + R
                    if vel.y < 0 { if -vel.y > 220 { squash = 1; squashT = 0.13 }; vel.y = -vel.y > 130 ? -vel.y * 0.72 : 0 }
                    onSurface = true
                }
                if pos.x > CGFloat(w) - R { pos.x = CGFloat(w) - R; if vel.x > 0 { vel.x = -vel.x * 0.75 } }
                if onSurface && abs(vel.y) < 8 { vel.x *= CGFloat(exp(-0.35 * simDt)); angle -= Double(vel.x / R) * simDt; spin = Double(-vel.x / R) }
                else { angle += spin * simDt }
                squashT -= simDt
            }
            if frame % 2 == 0 { trail.append(pos); if trail.count > 10 { trail.removeFirst() } }
        }
        if sway > 0 { sway = max(0, sway - 0.07) }
        let step = ((Int((angle / (.pi / 16)).rounded()) % 32) + 32) % 32
        let img = renderScene(w, h) {
            backdrop(w, h)
            hv.mirrored = false
            hv.sway = sway * CGFloat(sin(Double(frame) * 1.3)) * 9
            NSGraphicsContext.current?.saveGraphicsState()
            let tr = NSAffineTransform(); tr.translateX(by: hoopX, yBy: rimY - HoopView.rimLocalY); tr.concat()
            hv.draw(hv.bounds)
            NSGraphicsContext.current?.restoreGraphicsState()
            for (i, p) in trail.enumerated() {
                NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 0.07 + 0.03 * CGFloat(i)).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)).fill()
            }
            var p = Pose(); p.ball = true; p.ballStep = step; p.ballSquash = squashT > 0 ? squash : 0
            sprite(p, x: pos.x - 7.5 * 6, y: pos.y - 7 * 6, unit: 6, shadow: false)
            if frame < 8 { label("throw me ➜  farther = more points", x: 230, y: 300, size: 12, color: NSColor(white: 0.35, alpha: 1)) }
            if scoreFrame >= 0 && frame >= scoreFrame && frame < scoreFrame + 22 { bubble("SWISH! Downtown: +5", cx: 430, bottom: 250) }
        }
        frames.append((img, 0.055))
    }
    return frames
}

// MARK: social card for the website

func ogImage() -> CGImage {
    let w = 1200, h = 630
    return renderScene(w, h) {
        NSColor(srgbRed: 0.98, green: 0.976, blue: 0.961, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: w, height: h).fill()
        NSGradient(colors: [NSColor(srgbRed: 0.85, green: 0.47, blue: 0.34, alpha: 0.18), NSColor.clear])!
            .draw(in: NSRect(x: 0, y: 0, width: 1200, height: 630), relativeCenterPosition: NSPoint(x: 0.55, y: -0.35))
        let serif = NSFont(name: "Georgia", size: 64) ?? NSFont.systemFont(ofSize: 64)
        let sans = NSFont(name: "Poppins-Medium", size: 26) ?? NSFont.systemFont(ofSize: 26, weight: .medium)
        let ink = NSColor(srgbRed: 0.078, green: 0.078, blue: 0.075, alpha: 1)
        ("A tiny pixel crab" as NSString).draw(at: NSPoint(x: 90, y: 380), withAttributes: [.font: serif, .foregroundColor: ink])
        ("that lives on your Mac." as NSString).draw(at: NSPoint(x: 90, y: 305), withAttributes: [.font: serif, .foregroundColor: clawdOrange])
        ("Clawd: a free desktop companion for macOS" as NSString).draw(at: NSPoint(x: 94, y: 220), withAttributes: [.font: sans, .foregroundColor: NSColor(white: 0.35, alpha: 1)])
        ("Not affiliated with Anthropic" as NSString).draw(at: NSPoint(x: 94, y: 70), withAttributes: [.font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor(white: 0.55, alpha: 1)])
        NSGraphicsContext.current?.shouldAntialias = false
        drawClawd(Pose(eyes: .happy, armR: 5, legs: 1, bob: 1), unit: 15, origin: CGPoint(x: 900, y: 90))
    }
}
