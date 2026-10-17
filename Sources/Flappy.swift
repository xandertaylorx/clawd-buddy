import Cocoa

// MARK: - Flappy Clawd

final class GameCapturePanel: NSPanel {
    var onFlap: (() -> Void)?
    var onQuit: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func mouseDown(with event: NSEvent) { onFlap?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { onFlap?() } else if event.keyCode == 53 { onQuit?() }
    }
}

final class PipeView: NSView {
    var capAtBottom = false   // top pipes have their cap at the bottom
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.shouldAntialias = false
        let w = bounds.width, h = bounds.height
        let body = rgb(0.45, 0.78, 0.3), dark = rgb(0.25, 0.5, 0.2), light = rgb(0.65, 0.9, 0.45)
        func fill(_ c: NSColor, _ r: NSRect) { c.setFill(); r.fill() }
        fill(dark, NSRect(x: 4, y: 0, width: w - 8, height: h))
        fill(body, NSRect(x: 8, y: 0, width: w - 16, height: h))
        fill(light, NSRect(x: 12, y: 0, width: 8, height: h))
        let capY: CGFloat = capAtBottom ? 0 : h - 24
        fill(dark, NSRect(x: 0, y: capY, width: w, height: 24))
        fill(body, NSRect(x: 4, y: capY + 4, width: w - 8, height: 16))
        fill(light, NSRect(x: 8, y: capY + 4, width: 8, height: 16))
        NSGraphicsContext.current?.shouldAntialias = true
    }
}

final class PipePanel: NSPanel {
    let pipeView = PipeView(frame: .zero)
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 72, height: 100), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        contentView = pipeView
    }
    override var canBecomeKey: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

struct PipePair { var top: PipePanel; var bottom: PipePanel; var x: CGFloat; var gapY: CGFloat; var gap: CGFloat; var passed = false }

final class FlapState {
    var capture: GameCapturePanel?
    var pipes: [PipePair] = []
    var pool: [PipePanel] = []
    var vy: CGFloat = 0
    var phase = 0          // 0 waiting for the first flap, 1 playing, 2 game over
    var score = 0
    var t = 0.0
    var spawnIn = 0.0
    var overAt = 0.0
    var hudIn = 0.0
    var anchor = NSRect.zero
    var pending = false
}

extension Pet {
    @objc func toggleFlap() { if mode == .flap { endFlap() } else { startFlap() } }

    func startFlap() {
        if mode == .docked { fl.pending = true; undock(); return }
        guard mode == .desk else { return }
        hideTray()
        shelf.hide()
        perch = nil
        redockAt = nil
        let vis = screen.visibleFrame
        x = vis.minX + vis.width * 0.22
        y = vis.midY
        fl.phase = 0
        fl.vy = 0
        fl.score = 0
        fl.t = 0
        fl.spawnIn = 1.2
        fl.hudIn = 0
        fl.anchor = NSRect(x: vis.midX, y: vis.maxY - 80, width: 0, height: 0)
        let cap = GameCapturePanel(contentRect: vis, styleMask: [.borderless], backing: .buffered, defer: false)
        cap.isOpaque = false
        cap.backgroundColor = NSColor(white: 0, alpha: 0.18)
        cap.hasShadow = false
        cap.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        cap.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        cap.onFlap = { [weak self] in self?.flap() }
        cap.onQuit = { [weak self] in self?.endFlap() }
        fl.capture = cap
        NSApp.activate(ignoringOtherApps: true)
        cap.makeKeyAndOrderFront(nil)
        mode = .flap
        bubble.show("Flappy Clawd! Click or press space to flap. Esc quits.", hold: 60, typewriter: false)
    }

    func flap() {
        switch fl.phase {
        case 0:
            fl.phase = 1
            fl.vy = 480
            bubble.hide()
            Sfx.play(.flap)
        case 1:
            fl.vy = 480
            Sfx.play(.flap)
        default:
            break
        }
    }

    func spawnPipe() {
        let vis = screen.visibleFrame
        let gap = max(165, 215 - CGFloat(fl.score) * 3)
        let lo = vis.minY + 80 + gap / 2, hi = vis.maxY - 80 - gap / 2
        let center = CGFloat.random(in: lo...max(lo + 1, hi))
        let top = fl.pool.popLast() ?? PipePanel()
        let bottom = fl.pool.popLast() ?? PipePanel()
        top.pipeView.capAtBottom = true
        bottom.pipeView.capAtBottom = false
        top.pipeView.needsDisplay = true
        bottom.pipeView.needsDisplay = true
        let px = vis.maxX + 10
        top.setFrame(NSRect(x: px, y: center + gap / 2, width: 72, height: vis.maxY - (center + gap / 2)), display: true)
        bottom.setFrame(NSRect(x: px, y: vis.minY, width: 72, height: center - gap / 2 - vis.minY), display: true)
        top.orderFrontRegardless()
        bottom.orderFrontRegardless()
        fl.pipes.append(PipePair(top: top, bottom: bottom, x: px, gapY: center, gap: gap))
    }

    func flapTick(_ dt: Double, now: Double) {
        let vis = screen.visibleFrame
        fl.t += dt
        var p = Pose()
        switch fl.phase {
        case 0:
            y = vis.midY + 12 * CGFloat(sin(fl.t * 4))
            p.armL = Int(fl.t / 0.3) % 2 == 0 ? 4 : 1
            p.armR = Int(fl.t / 0.3) % 2 == 0 ? 1 : 4
            p.legs = 1
            p.eyes = .happy
            if fl.t > 45 { endFlap(); return }   // nobody's playing: give the screen back
        case 1, 2:
            fl.vy -= (fl.phase == 1 ? 1500 : 1800) * CGFloat(dt)
            y += fl.vy * CGFloat(dt)
            if fl.phase == 1 {
                p.legs = 1
                p.eyes = .wide
                p.armL = fl.vy > 0 ? 5 : 1
                p.armR = fl.vy > 0 ? 5 : 1
                if y + 62 >= vis.maxY { y = vis.maxY - 62; fl.vy = min(fl.vy, 0) }
                if y <= floorY { y = floorY; gameOverFlap() }
                let speed = min(340, 210 + CGFloat(fl.score) * 7)
                fl.spawnIn -= dt
                if fl.spawnIn <= 0 { spawnPipe(); fl.spawnIn = 1.5 }
                let me = CGRect(x: x + 20, y: y + 10, width: 50, height: 46)
                var keep: [PipePair] = []
                for var pp in fl.pipes {
                    pp.x -= speed * CGFloat(dt)
                    pp.top.setFrameOrigin(CGPoint(x: pp.x, y: pp.top.frame.minY))
                    pp.bottom.setFrameOrigin(CGPoint(x: pp.x, y: pp.bottom.frame.minY))
                    if pp.top.frame.insetBy(dx: 4, dy: 0).intersects(me) || pp.bottom.frame.insetBy(dx: 4, dy: 0).intersects(me) {
                        if fl.phase == 1 { gameOverFlap() }
                    }
                    if !pp.passed && pp.x + 72 < x + 20 {
                        pp.passed = true
                        fl.score += 1
                        Sfx.play(.score)
                    }
                    if pp.x < vis.minX - 90 {
                        pp.top.orderOut(nil); pp.bottom.orderOut(nil)
                        fl.pool.append(pp.top); fl.pool.append(pp.bottom)
                    } else {
                        keep.append(pp)
                    }
                }
                fl.pipes = keep
                fl.hudIn -= dt
                if fl.hudIn <= 0 && fl.phase == 1 {
                    fl.hudIn = 0.2
                    bubble.show("Score \(fl.score)", hold: 0.6, typewriter: false)
                }
            } else {
                p.eyes = .wide
                p.armL = 4; p.armR = 4
                p.legs = Int(fl.t / 0.1) % 2 + 1
                if y <= floorY { y = floorY; fl.vy = 0; p.squash = true }
                if now > fl.overAt + 1.6 { endFlap(); return }
            }
        default:
            break
        }
        view.pose = p
        moveWindow()
    }

    func gameOverFlap() {
        guard fl.phase == 1 else { return }
        fl.phase = 2
        fl.overAt = CACurrentMediaTime()
        fl.vy = 120
        Sfx.play(.hit)
        let best = UserDefaults.standard.integer(forKey: "flapBest")
        let isBest = fl.score > best
        if isBest { UserDefaults.standard.set(fl.score, forKey: "flapBest") }
        bubble.show("Game over! Score \(fl.score). " + (isBest ? "New best!" : "Best: \(best)"), hold: 4, typewriter: false)
    }

    func endFlap() {
        for pp in fl.pipes { pp.top.orderOut(nil); pp.bottom.orderOut(nil); fl.pool.append(pp.top); fl.pool.append(pp.bottom) }
        fl.pipes = []
        fl.capture?.orderOut(nil)
        fl.capture = nil
        bubble.hide()
        vy = 0
        mode = .falling
        brain.start(.idle, dur: 1)
    }
}
