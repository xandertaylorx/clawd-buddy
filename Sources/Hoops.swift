import Cocoa

// MARK: - Basketball: Clawd the ball, a hoop on the screen edge, farther shots score more

final class HoopView: NSView {
    var mirrored = false     // true when the hoop is on the left edge
    var sway: CGFloat = 0
    static let size = NSSize(width: 150, height: 190)
    static let rimLocalY: CGFloat = 62

    override func draw(_ dirtyRect: NSRect) {
        let W = bounds.width, ry = HoopView.rimLocalY
        NSGraphicsContext.current?.saveGraphicsState()
        if mirrored {
            let t = NSAffineTransform()
            t.translateX(by: W, yBy: 0)
            t.scaleX(by: -1, yBy: 1)
            t.concat()
        }
        let orange = clawdOrange, dark = rgb(0.72, 0.38, 0.26)
        // backboard slab on the wall side
        let board = NSBezierPath(roundedRect: NSRect(x: W - 16, y: ry - 10, width: 16, height: 130), xRadius: 3, yRadius: 3)
        NSColor.white.setFill(); board.fill()
        orange.setStroke(); board.lineWidth = 2; board.stroke()
        orange.setFill()
        NSRect(x: W - 14, y: ry + 6, width: 12, height: 30).fill()
        // net (behind the rim line)
        let xs: [CGFloat] = [16, 38, 60, 82, 104, 126]
        let cx: CGFloat = 71
        func bottom(_ x: CGFloat) -> CGPoint { CGPoint(x: cx + (x - cx) * 0.55 + sway, y: ry - 58) }
        NSColor(white: 1, alpha: 0.95).setStroke()
        for x in xs {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: x, y: ry - 2))
            p.line(to: bottom(x))
            p.lineWidth = 1.6
            p.stroke()
        }
        for t in [0.3, 0.55, 0.8] as [CGFloat] {
            let p = NSBezierPath()
            for (i, x) in xs.enumerated() {
                let b = bottom(x)
                let pt = NSPoint(x: x + (b.x - x) * t, y: (ry - 2) + (b.y - (ry - 2)) * t)
                if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
            }
            p.lineWidth = 1.4
            p.stroke()
        }
        // rim
        orange.setFill()
        NSRect(x: 10, y: ry - 2, width: W - 26, height: 5).fill()
        dark.setFill()
        NSBezierPath(ovalIn: NSRect(x: 6, y: ry - 5, width: 11, height: 11)).fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

final class HoopPanel: NSPanel {
    let hoopView = HoopView(frame: NSRect(origin: .zero, size: HoopView.size))
    init() {
        super.init(contentRect: NSRect(origin: .zero, size: HoopView.size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)   // Clawd always draws on top of it
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        contentView = hoopView
    }
    override var canBecomeKey: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class HoopState {
    var active = false
    var panel: HoopPanel?
    var side = 1               // 1 = hoop on the right edge, 0 = left
    var rimY: CGFloat = 0
    var front = CGPoint.zero   // the two rim ends
    var back = CGPoint.zero
    var board = CGRect.zero
    var score = 0
    var timeLeft = 60.0
    var shotFrom: CGPoint?
    var scored = false
    var touchedRim = false
    var relocateAt = 0.0
    var sway: CGFloat = 0
    var hudIn = 0.0
    var msgUntil = 0.0
    var anchor = NSRect.zero
}

extension Pet {
    @objc func toggleHoops() { if hoop.active { endHoops(finished: false) } else { startHoops() } }

    func startHoops() {
        if mode == .ball {
            beginHoops()
        } else if mode == .docked || mode == .desk {
            ball.pendingHoops = true
            startBall()      // docked: pops out first; the hook below begins the game once he's rolling
            if mode == .ball { ball.pendingHoops = false; beginHoops() }
        }
    }

    func beginHoops() {
        guard mode == .ball, !hoop.active else { return }
        hoop.active = true
        hoop.score = 0
        hoop.timeLeft = 60
        hoop.hudIn = 0
        hoop.msgUntil = 0
        hoop.relocateAt = 0
        hoop.shotFrom = nil
        hoop.panel = HoopPanel()
        relocateHoop()
        let vis = screen.visibleFrame
        hoop.anchor = NSRect(x: vis.midX, y: vis.maxY - 90, width: 0, height: 0)
        bubble.show("Basketball! Throw me through the hoop. Farther shots score more. 60 seconds!", hold: 4, typewriter: false)
        Sfx.play(.fanfare)
    }

    func relocateHoop() {
        guard let p = hoop.panel else { return }
        let scr = screen
        let fr = scr.frame, vis = scr.visibleFrame
        // usually on the far side from where the ball is, so there's a real shot to take
        hoop.side = (ball.pos.x < fr.midX) == (Double.random(in: 0..<1) < 0.8) ? 1 : 0
        let lo = vis.minY + 210, hi = vis.maxY - 190
        hoop.rimY = CGFloat.random(in: lo...max(lo + 1, hi))
        let W = HoopView.size.width
        let ox = hoop.side == 1 ? fr.maxX - W : fr.minX
        p.hoopView.mirrored = hoop.side == 0
        p.hoopView.sway = 0
        p.hoopView.needsDisplay = true
        p.setFrame(NSRect(x: ox, y: hoop.rimY - HoopView.rimLocalY, width: W, height: HoopView.size.height), display: true)
        if hoop.side == 1 {
            hoop.front = CGPoint(x: ox + 11, y: hoop.rimY)
            hoop.back = CGPoint(x: ox + W - 18, y: hoop.rimY)
            hoop.board = CGRect(x: ox + W - 16, y: hoop.rimY - 10, width: 16, height: 130)
        } else {
            hoop.front = CGPoint(x: ox + W - 11, y: hoop.rimY)
            hoop.back = CGPoint(x: ox + 18, y: hoop.rimY)
            hoop.board = CGRect(x: ox, y: hoop.rimY - 10, width: 16, height: 130)
        }
        hoop.scored = false
        p.orderFront(nil)
    }

    func endHoops(finished: Bool) {
        guard hoop.active else { return }
        hoop.active = false
        hoop.panel?.orderOut(nil)
        hoop.panel = nil
        guard mode == .ball else { return }
        if finished {
            let best = UserDefaults.standard.integer(forKey: "hoopsBest")
            let isBest = hoop.score > best
            if isBest { UserDefaults.standard.set(hoop.score, forKey: "hoopsBest") }
            Sfx.play(.fanfare)
            bubble.show("Time! \(hoop.score) point\(hoop.score == 1 ? "" : "s"). " + (isBest ? "New best!" : "Best: \(best)"), hold: 5, typewriter: false)
        } else {
            bubble.hide()
        }
    }

    /// Circle-vs-point and circle-vs-slab collisions for the rim and backboard. Called every physics substep.
    func hoopCollide(prevY: CGFloat) {
        let R = BallState.radius
        func bounce(_ n: CGPoint, e: CGFloat) {
            let vn = ball.vel.x * n.x + ball.vel.y * n.y
            if vn < 0 {
                ball.vel.x -= (1 + e) * vn * n.x
                ball.vel.y -= (1 + e) * vn * n.y
                ballImpact(-vn, axis: abs(n.x) > abs(n.y) ? 2 : 1)
            }
        }
        // backboard
        let b = hoop.board
        let cx = max(b.minX, min(ball.pos.x, b.maxX)), cy = max(b.minY, min(ball.pos.y, b.maxY))
        var dx = ball.pos.x - cx, dy = ball.pos.y - cy
        var d = hypot(dx, dy)
        if d < R {
            if d < 0.001 { dx = hoop.side == 1 ? -1 : 1; dy = 0; d = 1 }
            let n = CGPoint(x: dx / d, y: dy / d)
            ball.pos.x += n.x * (R - d)
            ball.pos.y += n.y * (R - d)
            bounce(n, e: 0.55)
        }
        // rim ends
        for pt in [hoop.front, hoop.back] {
            dx = ball.pos.x - pt.x
            dy = ball.pos.y - pt.y
            d = hypot(dx, dy)
            if d < R + 5 {
                if d < 0.001 { d = 1; dy = 1 }
                let n = CGPoint(x: dx / d, y: dy / d)
                ball.pos.x += n.x * (R + 5 - d)
                ball.pos.y += n.y * (R + 5 - d)
                bounce(n, e: 0.5)
                hoop.touchedRim = true
            }
        }
        // through the hoop, from above
        let lo = min(hoop.front.x, hoop.back.x) + 6, hi = max(hoop.front.x, hoop.back.x) - 6
        if !hoop.scored && prevY > hoop.rimY && ball.pos.y <= hoop.rimY && ball.vel.y < 0 && ball.pos.x > lo && ball.pos.x < hi {
            hoopScored()
        }
    }

    func hoopScored() {
        let now = CACurrentMediaTime()
        let from = hoop.shotFrom ?? ball.pos
        let rim = CGPoint(x: (hoop.front.x + hoop.back.x) / 2, y: hoop.rimY)
        let frac = hypot(from.x - rim.x, from.y - rim.y) / screen.frame.width
        let (base, name): (Int, String) = frac < 0.2 ? (1, "Layup") : (frac < 0.4 ? (2, "Mid-range") : (frac < 0.65 ? (3, "Long range") : (4, "Downtown")))
        let swish = !hoop.touchedRim
        let pts = base + (swish ? 1 : 0)
        hoop.score += pts
        UserDefaults.standard.set(hoop.score, forKey: "hoopsLast")
        hoop.scored = true
        hoop.relocateAt = now + 1.5
        hoop.sway = 1
        hoop.msgUntil = now + 1.4
        ball.vel.x *= 0.4
        ball.vel.y *= 0.55
        Sfx.play(swish ? .fanfare : .score)
        bubble.show((swish ? "SWISH! " : "") + "\(name): +\(pts)", hold: 1.5, typewriter: false)
    }

    func hoopsTick(_ dt: Double, now: Double) {
        hoop.timeLeft -= dt
        if hoop.sway > 0, let hv = hoop.panel?.hoopView {
            hoop.sway = max(0, hoop.sway - CGFloat(dt) * 1.2)
            hv.sway = hoop.sway * CGFloat(sin(now * 20)) * 9
            hv.needsDisplay = true
        }
        if hoop.relocateAt > 0 && now > hoop.relocateAt {
            hoop.relocateAt = 0
            relocateHoop()
        }
        hoop.hudIn -= dt
        if hoop.hudIn <= 0 && now > hoop.msgUntil {
            hoop.hudIn = 0.3
            bubble.show("Score \(hoop.score)   ·   \(max(0, Int(hoop.timeLeft.rounded(.up))))s", hold: 0.7, typewriter: false)
        }
        if hoop.timeLeft <= 0 { endHoops(finished: true) }
    }
}

