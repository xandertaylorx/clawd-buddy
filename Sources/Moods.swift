import Cocoa

// MARK: - Rare weird moods: sneeze, ghost, peek-a-boo, building a fort on a window

enum MoodKind { case sneeze, ghost, peek, fort }

final class BrickView: NSView {
    var flag = false
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.shouldAntialias = false
        if flag {
            rgb(0.35, 0.25, 0.2).setFill()
            NSRect(x: 8, y: 0, width: 2, height: 24).fill()
            clawdOrange.setFill()
            NSRect(x: 10, y: 14, width: 10, height: 8).fill()
            return
        }
        rgb(0.62, 0.6, 0.62).setFill()
        bounds.fill()
        rgb(0.45, 0.43, 0.47).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 2).fill()
        NSRect(x: bounds.width / 2 - 1, y: 0, width: 2, height: bounds.height).fill()
        rgb(0.78, 0.76, 0.78).setFill()
        NSRect(x: 2, y: bounds.height - 3, width: bounds.width - 4, height: 2).fill()
    }
}

final class BrickPanel: NSPanel {
    let brick = BrickView(frame: NSRect(x: 0, y: 0, width: 20, height: 14))
    init(flag: Bool = false) {
        let size = flag ? NSSize(width: 22, height: 26) : NSSize(width: 20, height: 14)
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        brick.flag = flag
        brick.frame = NSRect(origin: .zero, size: size)
        contentView = brick
    }
    override var canBecomeKey: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

struct Brick { var panel: BrickPanel; var from: CGPoint; var to: CGPoint; var t: Double; var landed: Bool }

final class MoodState {
    var kind = MoodKind.sneeze
    var t = 0.0
    var dur = 3.0
    var said = 0
    var nextAt = CACurrentMediaTime() + 150
    var home = CGPoint.zero
    var edge = 0   // 0 bottom, 1 left, 2 right
    var scared = false
    var bricks: [Brick] = []
    var targets: [(CGPoint, Bool)] = []
    var placed = 0
    var spawnIn = 0.0
    var fortRect = CGRect.zero
    var pendingFort = false
    var lastCheck = 0.0
    var said_t = 0.0
    var doneAt = 0.0
}

extension Pet {
    func lerp(_ a: CGFloat, _ b: CGFloat, _ u: Double) -> CGFloat { a + (b - a) * CGFloat(u) }
    func ease(_ u: Double) -> Double { let c = max(0, min(1, u)); return c * c * (3 - 2 * c) }

    /// Called every second: maybe start something weird.
    func moodScheduler(_ mono: Double) {
        guard mode == .desk, mono > mood.nextAt, !isQuiet, focusEnd == nil, !claudeWorking,
              !userIdle, downloads == 0, !trayUp, dev.attentionUntil == 0 else { return }
        mood.nextAt = mono + .random(in: 240...600)
        let r = Double.random(in: 0..<100)
        if r < 25 { startMood(.sneeze) } else if r < 50 { startMood(.ghost) } else if r < 78 { startMood(.peek) } else { startMood(.fort) }
    }

    func startMood(_ kind: MoodKind) {
        if mode == .docked { return }
        guard mode == .desk else { return }
        hideTray()
        mood.kind = kind
        mood.t = 0
        mood.said = 0
        mood.scared = false
        mood.home = CGPoint(x: x, y: y)
        switch kind {
        case .sneeze: mood.dur = 2.8
        case .ghost: mood.dur = 5.5
        case .peek:
            mood.dur = 8
            mood.edge = Int.random(in: 0...2)
            perch = nil
        case .fort:
            guard let t = perchCandidates().randomElement() else { startMood(.peek); return }
            mood.pendingFort = true
            perch = nil
            startHop(to: t)
            return
        }
        mode = .mood
    }

    func beginFort() {
        guard let p = perch else { return }
        mood.kind = .fort
        mood.t = 0
        mood.dur = 60
        mood.said = 0
        mood.fortRect = p.rect
        mood.placed = 0
        mood.spawnIn = 0.4
        mood.lastCheck = 0
        let cx = x + Pet.size.width / 2
        let top = p.rect.maxY
        var targets: [(CGPoint, Bool)] = []
        for side in [-1, 1] {
            let outer = cx + CGFloat(side) * 64
            for row in 0..<3 {
                for col in 0..<2 {
                    let bx = outer + CGFloat(side) * CGFloat(col) * 22 - 10
                    targets.append((CGPoint(x: bx, y: top + CGFloat(row) * 14), false))
                }
            }
            targets.append((CGPoint(x: outer + CGFloat(side) * 22 - 10 + CGFloat(side) * 22 * (side > 0 ? 0 : 0), y: top + 42), false))
        }
        targets.append((CGPoint(x: cx + 64 + 22 - 11, y: top + 56), true))   // flag on the right tower
        mood.targets = targets
        mood.bricks = []
        mode = .mood
        say("Time to build a fort.", hold: 2.5)
        Sfx.play(.click)
    }

    func cancelMood() {
        for b in mood.bricks { b.panel.orderOut(nil) }
        mood.bricks = []
        panel.alphaValue = 1
        mood.pendingFort = false
    }

    func endMood() {
        cancelMood()
        panel.alphaValue = 1
        if perch == nil { y = floorY }
        mode = .desk
        brain.start(.idle, dur: 1)
    }

    func moodTick(_ dt: Double, now: Double) {
        mood.t += dt
        let t = mood.t
        var p = Pose()
        let vis = screen.visibleFrame
        let mouse = NSEvent.mouseLocation
        switch mood.kind {
        case .sneeze:
            if t < 1.0 { p.eyes = .blink; p.armR = Int(t * 3); p.bob = Int(t / 0.25) % 2
                if mood.said == 0 { mood.said = 1; say("…ah…", hold: 1.2, typewriter: false) } }
            else if t < 1.7 { p.eyes = .sleep; p.eyeLift = 1; p.armL = 3; p.armR = 3
                if mood.said == 1 { mood.said = 2; say("…ahh…", hold: 1.2, typewriter: false) } }
            else {
                p.eyes = .sleep; p.squash = true
                if mood.said == 2 { mood.said = 3; say("ACHOO!", hold: 1.5, typewriter: false); Sfx.play(.poof) }
                let u = min(1, (t - 1.7) / 0.35)
                x = mood.home.x - CGFloat(1 - u) * 0 + (CGFloat(u) < 1 ? -22 * CGFloat(sin(u * .pi)) : 0)
            }
            y = groundY
        case .ghost:
            let a = 0.4 + 0.15 * sin(t * 4)
            panel.alphaValue = CGFloat(t > mood.dur - 0.6 ? max(0.01, (mood.dur - t) / 0.6) * a + (1 - (mood.dur - t) / 0.6) * 1 : a)
            y = groundY + 14 + 10 * CGFloat(sin(t * 3))
            x += 24 * CGFloat(dt) * (mood.edge == 0 ? 1 : -1)
            x = min(max(x, vis.minX), vis.maxX - Pet.size.width)
            p.eyes = .wide; p.armL = Int(t / 0.3) % 2 == 0 ? 4 : 3; p.armR = Int(t / 0.3) % 2 == 0 ? 3 : 4
            if mood.said == 0 && t > 0.5 { mood.said = 1; say("Boo!", hold: 1.5, typewriter: false); Sfx.play(.whoosh) }
        case .peek:
            let hidden: CGPoint, peek: CGPoint
            let f = screen.frame
            switch mood.edge {
            case 0: hidden = CGPoint(x: mood.home.x, y: f.minY - 100); peek = CGPoint(x: mood.home.x, y: f.minY - 22)
            case 1: hidden = CGPoint(x: f.minX - 100, y: mood.home.y); peek = CGPoint(x: f.minX - 60, y: mood.home.y)
            default: hidden = CGPoint(x: f.maxX + 10, y: mood.home.y); peek = CGPoint(x: f.maxX - 36, y: mood.home.y)
            }
            let home = CGPoint(x: mood.home.x, y: groundY)
            var pos: CGPoint
            if mood.scared {
                let u = ease((t - mood.said_t) / 0.35)
                pos = CGPoint(x: lerp(peek.x, home.x, u), y: lerp(peek.y, home.y, u) + CGFloat(sin(u * .pi)) * 40)
                p.eyes = .happy; p.armL = 4; p.armR = 4
                if u >= 1 { endMood(); return }
            } else if t < 0.6 {
                pos = CGPoint(x: lerp(home.x, hidden.x, ease(t / 0.6)), y: lerp(home.y, hidden.y, ease(t / 0.6)))
                p.legs = Int(t / 0.1) % 2 + 1
            } else if t < 1.9 {
                pos = hidden
            } else if t < 2.5 {
                let u = ease((t - 1.9) / 0.6)
                pos = CGPoint(x: lerp(hidden.x, peek.x, u), y: lerp(hidden.y, peek.y, u))
            } else if t < mood.dur - 1 {
                pos = peek
                p.eyeShift = mouse.x > pos.x + 48 ? 1 : -1
                p.eyes = Int(t / 0.5) % 5 == 0 ? .blink : .open
                let c = CGPoint(x: pos.x + 48, y: pos.y + 40)
                if hypot(mouse.x - c.x, mouse.y - c.y) < 170 { mood.scared = true; mood.said_t = t; say("Boo!", hold: 1.5, typewriter: false); Sfx.play(.hop) }
            } else {
                let u = ease((t - (mood.dur - 1)) / 0.7)
                pos = CGPoint(x: lerp(peek.x, home.x, u), y: lerp(peek.y, home.y, u))
                if u >= 1 { endMood(); return }
            }
            x = pos.x; y = pos.y
        case .fort:
            fortTick(dt, now: now, &p)
            if mode != .mood { return }
        }
        if mood.kind != .peek && mood.kind != .fort && t >= mood.dur { endMood(); return }
        view.pose = p
        moveWindow()
    }

    func fortTick(_ dt: Double, now: Double, _ p: inout Pose) {
        let t = mood.t
        // the window we're building on must still be there
        if mood.lastCheck + 1 < t {
            mood.lastCheck = t
            if let cur = windowRects().first(where: { $0.id == perch?.id }), abs(cur.rect.maxY - mood.fortRect.maxY) < 3,
               abs(cur.rect.minX - mood.fortRect.minX) < 3 {
                // still there
            } else {
                say("My fort!", hold: 2)
                leavePerch()
                for b in mood.bricks { b.panel.orderOut(nil) }
                mood.bricks = []
                mode = .falling
                return
            }
        }
        y = groundY
        let s = Int(t / 0.12)
        if mood.placed < mood.targets.count {
            p.eyes = .happy
            p.armL = s % 2 == 0 ? 4 : 1; p.armR = s % 2 == 0 ? 1 : 4
            p.bob = s % 2
            mood.spawnIn -= dt
            if mood.spawnIn <= 0 {
                let tg = mood.targets[mood.placed]
                let bp = BrickPanel(flag: tg.1)
                bp.setFrameOrigin(CGPoint(x: x + 80, y: y + 40))
                bp.orderFrontRegardless()
                mood.bricks.append(Brick(panel: bp, from: CGPoint(x: x + 80, y: y + 40), to: tg.0, t: 0, landed: false))
                mood.placed += 1
                mood.spawnIn = 0.32
            }
        } else if mood.bricks.allSatisfy({ $0.landed }) {
            if mood.said == 0 { mood.said = 1; mood.doneAt = t; say("Fort complete. 🏰", hold: 5); Sfx.play(.fanfare) }
            p.squash = true; p.eyes = .happy
            if t > mood.doneAt + 5.5 {
                for b in mood.bricks { b.panel.orderOut(nil) }
                Sfx.play(.poof)
                mood.bricks = []
                endMood()
                return
            }
        }
        for i in mood.bricks.indices where !mood.bricks[i].landed {
            mood.bricks[i].t += dt
            let u = min(1, mood.bricks[i].t / 0.3)
            let b = mood.bricks[i]
            b.panel.setFrameOrigin(CGPoint(x: lerp(b.from.x, b.to.x, u), y: lerp(b.from.y, b.to.y, u) + CGFloat(sin(u * .pi)) * 30))
            if u >= 1 { mood.bricks[i].landed = true; Sfx.play(.drop, volume: 0.2) }
        }
    }
}
