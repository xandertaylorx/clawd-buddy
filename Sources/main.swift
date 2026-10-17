import Cocoa
import ServiceManagement
import IOKit.ps
import EventKit
import Carbon.HIToolbox

// MARK: - Palette

let clawdOrange = NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1)
let clawdInk = NSColor(srgbRed: 0.10, green: 0.07, blue: 0.06, alpha: 1)
let bubbleCream = NSColor(srgbRed: 0.98, green: 0.976, blue: 0.961, alpha: 1)

// MARK: - Pose + sprite drawing (everything is drawn from rectangles, pixel-art style)

enum Eyes { case open, blink, happy, sleep, wide }

struct Pose: Hashable {
    var eyes: Eyes = .open
    var eyeShift = 0   // -1...1 look left/right
    var eyeLift = 0    // 1 = look up
    var armL = 0       // arm raise in sprite pixels
    var armR = 0
    var legs = 0       // 0 = flat, 1/2 = alternating diagonal pairs lifted
    var bob = 0
    var squash = false
    var hat: Hat = .none
    var timer: Int? = nil      // when set, Clawd turns into a timer showing these two digits
    var timerBar = 0           // 0...9 cells of progress bar left
    var timerSecs = false      // last minute: digits are seconds
    var timerBreak = false
}

enum Hat: String { case none, party, santa, wizard, crown, pumpkin }

let canvasW = 15
let canvasH = 14
let iconRows = 12

let digitFont: [[String]] = [
    ["111", "101", "101", "101", "111"], ["010", "110", "010", "010", "111"],
    ["111", "001", "111", "100", "111"], ["111", "001", "111", "001", "111"],
    ["101", "101", "111", "001", "001"], ["111", "100", "111", "001", "111"],
    ["111", "100", "111", "101", "111"], ["111", "001", "001", "001", "001"],
    ["111", "101", "111", "101", "111"], ["111", "101", "111", "001", "111"],
]

func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }

func drawClawd(_ p: Pose, unit u: CGFloat, origin o: CGPoint) {
    func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: NSColor) {
        c.setFill()
        NSRect(x: o.x + CGFloat(x) * u, y: o.y + CGFloat(y) * u,
               width: CGFloat(w) * u, height: CGFloat(h) * u).fill()
    }
    let sq = p.squash ? 1 : 0
    let b = 2 - sq + (p.squash ? 0 : p.bob)   // body base row
    let bodyH = (p.timer != nil ? 9 : 6) - sq

    // legs
    for (i, x) in [3, 5, 9, 11].enumerated() {
        let lifted = (p.legs == 1 && (i == 0 || i == 3)) || (p.legs == 2 && (i == 1 || i == 2))
        if p.squash {
            if !lifted { rect(x, 0, 1, 1, clawdOrange) }
        } else if lifted {
            rect(x, 1, 1, 1, clawdOrange)
        } else {
            rect(x, 0, 1, 2, clawdOrange)
        }
    }
    // body
    rect(2, b, 11, bodyH, clawdOrange)
    // arms
    rect(0, b + 1 + p.armL, 2, 2, clawdOrange)
    rect(13, b + 1 + p.armR, 2, 2, clawdOrange)
    if p.armL > 1 { rect(1, b + 1, 1, p.armL + 2, clawdOrange) }   // keep raised arms attached
    if p.armR > 1 { rect(13, b + 1, 1, p.armR + 2, clawdOrange) }
    // timer form: the body becomes an LCD with a draining progress bar and little alarm bells
    if let digits = p.timer {
        rect(3, b + 9, 2, 1, clawdOrange)
        rect(10, b + 9, 2, 1, clawdOrange)
        rect(3, b + 1, 9, 7, p.timerBreak ? rgb(0.80, 0.91, 0.96) : bubbleCream)
        for i in 0..<9 { rect(3 + i, b, 1, 1, i < p.timerBar ? clawdInk : rgb(0.72, 0.38, 0.26)) }
        let ds = [min(9, digits / 10), digits % 10]
        for (k, d) in ds.enumerated() {
            for (row, line) in digitFont[d].enumerated() {
                for (col, ch) in line.enumerated() where ch == "1" {
                    rect(4 + k * 4 + col, b + 6 - row, 1, 1, clawdInk)
                }
            }
        }
        if p.timerSecs { rect(7, b + 3, 1, 1, clawdInk); rect(7, b + 5, 1, 1, clawdInk) }
        return
    }
    // hat
    let top = b + bodyH
    switch p.hat {
    case .none: break
    case .party:
        rect(5, top, 5, 1, rgb(0.55, 0.35, 0.85)); rect(6, top + 1, 3, 1, rgb(0.55, 0.35, 0.85))
        rect(7, top + 2, 1, 1, rgb(0.55, 0.35, 0.85)); rect(7, top + 3, 1, 1, rgb(1, 0.85, 0.2))
    case .santa:
        rect(4, top, 7, 1, .white); rect(5, top + 1, 5, 1, rgb(0.85, 0.15, 0.15))
        rect(6, top + 2, 3, 1, rgb(0.85, 0.15, 0.15)); rect(8, top + 3, 2, 1, .white)
    case .wizard:
        rect(3, top, 9, 1, rgb(0.25, 0.25, 0.6)); rect(5, top + 1, 5, 1, rgb(0.25, 0.25, 0.6))
        rect(6, top + 2, 3, 1, rgb(0.25, 0.25, 0.6)); rect(7, top + 3, 1, 1, rgb(0.25, 0.25, 0.6))
        rect(7, top + 1, 1, 1, rgb(1, 0.85, 0.2))
    case .crown:
        rect(4, top, 7, 1, rgb(0.95, 0.78, 0.2))
        for x in [4, 7, 10] { rect(x, top + 1, 1, 1, rgb(0.95, 0.78, 0.2)) }
    case .pumpkin:
        rect(4, top, 7, 2, rgb(0.96, 0.55, 0.12)); rect(5, top + 2, 5, 1, rgb(0.96, 0.55, 0.12))
        rect(7, top + 3, 1, 1, rgb(0.3, 0.6, 0.2))
    }
    // eyes
    let ey = b + 2 + p.eyeLift
    for ex in [4 + p.eyeShift, 10 + p.eyeShift] {
        switch p.eyes {
        case .open: rect(ex, ey, 1, 2, clawdInk)
        case .blink: rect(ex, ey, 1, 1, clawdInk)
        case .wide: rect(ex, ey, 2, 3, clawdInk)
        case .happy:
            rect(ex - 1, ey, 1, 1, clawdInk)
            rect(ex, ey + 1, 1, 1, clawdInk)
            rect(ex + 1, ey, 1, 1, clawdInk)
        case .sleep: rect(ex - 1, ey, 3, 1, clawdInk)
        }
    }
}

func spriteImage(_ pose: Pose, unit: CGFloat) -> NSImage {
    let size = NSSize(width: CGFloat(canvasW) * unit, height: CGFloat(iconRows) * unit)
    let img = NSImage(size: size, flipped: false) { _ in
        NSGraphicsContext.current?.shouldAntialias = false
        drawClawd(pose, unit: unit, origin: .zero)
        return true
    }
    img.isTemplate = false
    return img
}

func writePNG(_ img: NSImage, to path: String) {
    guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

// MARK: - Words (Claude Code flavoured)

enum Words {
    static let spinner = ["Pondering", "Flibbertigibbeting", "Clauding", "Percolating", "Noodling",
                          "Spelunking", "Cogitating", "Moonwalking", "Gallivanting", "Combobulating",
                          "Discombobulating", "Shenaniganing", "Reticulating splines", "Marinating",
                          "Simmering", "Wrangling", "Tinkering", "Herding electrons", "Befuddling",
                          "Whirring", "Schlepping", "Brewing", "Musing"]
    static let quips = ["You're absolutely right!", "Let me take a look at that.",
                        "I'll just make one small change…", "Tests are passing. Probably.",
                        "Have you tried turning it off and on?", "It works on my machine.",
                        "Ooh, a bug!", "Shall I proceed?", "This is fine.", "Is it Friday yet?",
                        "I need more tokens.", "Reading the whole codebase…", "Drink some water!",
                        "Stretch your legs!", "Remember to commit.", "No bugs here. Suspicious.",
                        "I can fix that.", "Want me to add tests?", "Looks good to me!",
                        "Hi! I'm Clawd.", "Just vibing.", "Compiling thoughts…", "*scuttles*",
                        "Let me think about this.", "Ship it!"]
    static let greetings = ["Hi!", "Hello!", "Hey you!", "o/", "Oh, hi!"]
    static let hops = ["Boing!", "Wheee!", "Hup!", "Yippee!"]

    static func random(short: Bool) -> String {
        var pool = quips + spinner.map { "✻ \($0)…" }
        let h = Calendar.current.component(.hour, from: Date())
        if h >= 23 || h < 5 { pool += ["It's late. Go to bed?", "Sleep is a feature."] }
        if short { pool = pool.filter { $0.count <= 24 } }
        return pool.randomElement() ?? "Hi!"
    }
    static func spinnerLine() -> String { "✻ \(spinner.randomElement()!)…" }
}

// MARK: - Brain: picks random activities and produces a pose each tick

enum Act { case idle, walk, jump, wave, dance, sleep, look, think, work, chase }

final class Brain {
    var act = Act.idle
    var t = 0.0
    var dur = 2.0
    var dir: CGFloat = 1
    var pose = Pose()
    var vx: CGFloat = 0
    var jumpY: CGFloat = 0
    var jumpH: CGFloat = 46
    var blinkIn = 3.0
    var blinkLeft = 0.0
    var onStart: ((Act) -> Void)?
    /// A forced activity (timer, Claude Code working, user away). Brief one-offs like hops still play over it.
    var override: Act? {
        didSet {
            if let o = override { if o != act { act = o; t = 0; dur = 1e9; onStart?(o) } }
            else if oldValue != nil { start(.idle, dur: 0.6) }
        }
    }

    func start(_ a: Act, dur d: Double? = nil) {
        act = a
        t = 0
        switch a {
        case .idle: dur = d ?? .random(in: 1.5...4)
        case .walk: dur = d ?? .random(in: 2...6); dir = Bool.random() ? 1 : -1
        case .look: dur = 2.4
        case .wave: dur = 1.8
        case .jump: dur = 0.7; jumpH = .random(in: 36...62)
        case .dance: dur = 2.6
        case .think: dur = 3.2
        case .sleep: dur = d ?? .random(in: 9...15)
        case .work: dur = d ?? 1e9
        case .chase: dur = 5
        }
        onStart?(a)
    }

    func pickNext() {
        switch Double.random(in: 0..<100) {
        case ..<24: start(.idle)
        case ..<50: start(.walk)
        case ..<59: start(.look)
        case ..<66: start(.wave)
        case ..<75: start(.jump)
        case ..<80: start(.dance)
        case ..<86: start(.think)
        case ..<92: start(.chase)
        default: start(.sleep)
        }
    }

    func update(_ dt: Double) {
        t += dt
        if t >= dur {
            if let o = override { act = o; t = 0; dur = 1e9 } else { pickNext() }
        }
        var p = Pose()
        vx = 0
        jumpY = 0
        switch act {
        case .idle:
            p.bob = Int(t / 0.8) % 2
        case .walk:
            let s = Int(t / 0.16)
            p.legs = s % 2 == 0 ? 1 : 2
            p.bob = s % 2
            p.eyeShift = Int(dir)
            vx = dir * 70
        case .look:
            let seq = [-1, -1, 0, 1, 1, 0]
            p.eyeShift = seq[min(Int(t / 0.4), seq.count - 1)]
        case .wave:
            p.eyes = .happy
            p.armR = Int(t / 0.18) % 2 == 0 ? 5 : 3
        case .jump:
            let u = min(t / dur, 1)
            jumpY = CGFloat(4 * Double(jumpH) * u * (1 - u))
            if u < 0.1 || u > 0.9 { p.squash = true } else { p.armL = 3; p.armR = 3; p.eyes = .happy }
        case .dance:
            let s = Int(t / 0.22)
            let even = s % 2 == 0
            p.eyes = .happy
            p.armL = even ? 5 : 1
            p.armR = even ? 1 : 5
            p.bob = s % 2
            p.legs = even ? 1 : 2
            vx = (s / 4) % 2 == 0 ? 18 : -18
        case .sleep:
            p.eyes = .sleep
            p.squash = true
        case .think:
            p.eyeLift = 1
            p.eyeShift = 1
            p.armR = 2
        case .work:
            let s = Int(t / 0.12)
            p.eyeShift = -1
            p.armL = s % 2
            p.armR = (s + 1) % 2
        case .chase:
            let s = Int(t / 0.09)
            p.legs = s % 2 == 0 ? 1 : 2
            p.bob = s % 2
            p.eyeShift = Int(dir)
            p.eyes = .wide
            vx = dir * 170
        }
        if blinkLeft > 0 {
            blinkLeft -= dt
        } else {
            blinkIn -= dt
            if blinkIn <= 0 { blinkLeft = 0.13; blinkIn = .random(in: 2...5) }
        }
        if blinkLeft > 0 && p.eyes == .open { p.eyes = .blink }
        pose = p
    }
}

// MARK: - Sprite window

final class SpritePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class SpriteView: NSView {
    static let unit: CGFloat = 6
    var pose = Pose() { didSet { if pose != oldValue { needsDisplay = true } } }
    var scale: CGFloat = 1 { didSet { if scale != oldValue { needsDisplay = true } } }
    var onDragStart: (() -> Void)?
    var onDragMove: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onClick: (() -> Void)?
    var onHold: (() -> Void)?
    var onDragEnter: (() -> Void)?
    var onDragLeave: (() -> Void)?
    var onDrop: (([URL], String?) -> Bool)?
    var menuProvider: (() -> NSMenu)?
    private var grab = CGPoint.zero
    private var downAt = CGPoint.zero
    private var moved = false
    private var held = false
    private var holdTimer: Timer?

    override init(frame f: NSRect) {
        super.init(frame: f)
        registerForDraggedTypes([.fileURL, .string])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ s: NSDraggingInfo) -> NSDragOperation { onDragEnter?(); return .copy }
    override func draggingExited(_ s: NSDraggingInfo?) { onDragLeave?() }
    override func performDragOperation(_ s: NSDraggingInfo) -> Bool {
        let pb = s.draggingPasteboard
        let urls = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        return onDrop?(urls, urls.isEmpty ? pb.string(forType: .string) : nil) ?? false
    }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.shouldAntialias = false
        let u = SpriteView.unit * scale
        let cw = CGFloat(canvasW) * u, ch = CGFloat(canvasH) * u
        let cx = bounds.midX
        let cy = 4 + CGFloat(canvasH) * SpriteView.unit / 2
        drawClawd(pose, unit: u, origin: CGPoint(x: cx - cw / 2, y: cy - ch / 2))
    }

    override func mouseDown(with event: NSEvent) {
        let m = NSEvent.mouseLocation
        downAt = m
        let o = window?.frame.origin ?? .zero
        grab = CGPoint(x: m.x - o.x, y: m.y - o.y)
        moved = false
        held = false
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: false) { [weak self] _ in
            guard let self, !self.moved else { return }
            self.held = true
            self.onHold?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let m = NSEvent.mouseLocation
        if !moved {
            guard hypot(m.x - downAt.x, m.y - downAt.y) > 3 else { return }
            moved = true
            holdTimer?.invalidate()
            onDragStart?()
        }
        window?.setFrameOrigin(CGPoint(x: m.x - grab.x, y: m.y - grab.y))
        onDragMove?()
    }

    override func mouseUp(with event: NSEvent) {
        holdTimer?.invalidate()
        if moved { onDragEnd?() } else if !held { onClick?() }
        moved = false
        held = false
    }

    override func rightMouseDown(with event: NSEvent) {
        if let m = menuProvider?() { NSMenu.popUpContextMenu(m, with: event, for: self) }
    }
}

// MARK: - Speech bubble

final class BubbleView: NSView {
    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    static let tailH: CGFloat = 7
    var text = ""
    var shown = 0
    var tailX: CGFloat = 20
    override var isFlipped: Bool { false }

    private var attrs: [NSAttributedString.Key: Any] {
        [.font: BubbleView.font, .foregroundColor: clawdInk]
    }

    func fit() -> NSSize {
        let r = (text as NSString).boundingRect(with: NSSize(width: 230, height: CGFloat.greatestFiniteMagnitude),
                                                options: [.usesLineFragmentOrigin], attributes: attrs)
        return NSSize(width: ceil(r.width) + 22, height: ceil(r.height) + 14 + BubbleView.tailH + 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        let body = NSRect(x: 1, y: BubbleView.tailH + 1, width: bounds.width - 2,
                          height: bounds.height - BubbleView.tailH - 2)
        let path = NSBezierPath(roundedRect: body, xRadius: 9, yRadius: 9)
        let tx = min(max(tailX, 16), bounds.width - 16)
        path.move(to: NSPoint(x: tx - 6, y: body.minY))
        path.line(to: NSPoint(x: tx, y: 1))
        path.line(to: NSPoint(x: tx + 6, y: body.minY))
        bubbleCream.setFill()
        path.fill()
        clawdOrange.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        let s = String(text.prefix(max(0, shown))) as NSString
        s.draw(with: body.insetBy(dx: 10, dy: 7), options: [.usesLineFragmentOrigin], attributes: attrs)
    }
}

final class Bubble {
    let panel: NSPanel
    let view = BubbleView()
    private var born = 0.0
    private var until = 0.0
    private var typewriter = true

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = view
    }

    var isVisible: Bool { panel.isVisible }

    func show(_ text: String, hold: Double, typewriter tw: Bool = true) {
        let now = CACurrentMediaTime()
        view.text = text
        view.shown = tw ? 0 : text.count
        typewriter = tw
        panel.setContentSize(view.fit())
        view.frame = NSRect(origin: .zero, size: panel.frame.size)
        view.needsDisplay = true
        born = now
        until = now + hold + (tw ? Double(text.count) / 35 : 0)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    func hide() { panel.orderOut(nil) }

    func update(anchor: NSRect, screenFrame sf: NSRect, topInset: CGFloat, now: Double) {
        guard panel.isVisible else { return }
        if now > until { hide(); return }
        panel.alphaValue = min(1, CGFloat((until - now) / 0.3))
        if typewriter {
            let n = max(0, min(view.text.count, Int((now - born) * 35)))
            if n != view.shown { view.shown = n; view.needsDisplay = true }
        }
        let w = panel.frame.width, h = panel.frame.height
        let x = min(max(anchor.midX - w / 2, sf.minX + 4), sf.maxX - w - 4)
        let y = min(anchor.maxY - 2, sf.maxY - topInset - h)
        view.tailX = anchor.midX - x
        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }
}

// MARK: - Drop tray (appears when you drag files over Clawd) and file shelf

enum Tile: CaseIterable {
    case hold, png, jpg, shrink, zip, path, trash
    var icon: String {
        switch self {
        case .hold: return "📥"
        case .png, .jpg: return "🖼"
        case .shrink: return "📉"
        case .zip: return "🗜"
        case .path: return "📋"
        case .trash: return "🗑"
        }
    }
    var label: String {
        switch self {
        case .hold: return "Hold"
        case .png: return "→ PNG"
        case .jpg: return "→ JPG"
        case .shrink: return "Shrink"
        case .zip: return "Zip"
        case .path: return "Path"
        case .trash: return "Trash"
        }
    }
}

final class TileView: NSView {
    let kind: Tile
    var hot = false { didSet { needsDisplay = true } }
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    var onDrop: ((Tile, [URL]) -> Void)?

    init(kind: Tile, frame: NSRect) {
        self.kind = kind
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: r, xRadius: 9, yRadius: 9)
        (hot ? clawdOrange : bubbleCream).setFill()
        path.fill()
        clawdOrange.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        let icon = kind.icon as NSString
        let iconAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 20)]
        let isz = icon.size(withAttributes: iconAttrs)
        icon.draw(at: NSPoint(x: bounds.midX - isz.width / 2, y: bounds.height - isz.height - 5), withAttributes: iconAttrs)
        let label = kind.label as NSString
        let la: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
                                                 .foregroundColor: hot ? NSColor.white : clawdInk]
        let lsz = label.size(withAttributes: la)
        label.draw(at: NSPoint(x: bounds.midX - lsz.width / 2, y: 6), withAttributes: la)
    }

    override func draggingEntered(_ s: NSDraggingInfo) -> NSDragOperation { hot = true; onEnter?(); return .copy }
    override func draggingExited(_ s: NSDraggingInfo?) { hot = false; onExit?() }
    override func performDragOperation(_ s: NSDraggingInfo) -> Bool {
        hot = false
        let urls = (s.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                     options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard !urls.isEmpty else { return false }
        onDrop?(kind, urls)
        return true
    }
}

final class DropTray {
    let panel: NSPanel
    var tiles: [TileView] = []

    init() {
        let n = Tile.allCases.count
        let w = CGFloat(n) * 54 + CGFloat(n - 1) * 6 + 16
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: w, height: 70), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        let content = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        panel.contentView = content
        for (i, k) in Tile.allCases.enumerated() {
            let t = TileView(kind: k, frame: NSRect(x: 8 + CGFloat(i) * 60, y: 8, width: 54, height: 54))
            content.addSubview(t)
            tiles.append(t)
        }
    }

    func show() { panel.alphaValue = 1; panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }
    var isVisible: Bool { panel.isVisible }

    func follow(anchor: NSRect, screenFrame sf: NSRect, topInset: CGFloat) {
        let w = panel.frame.width, h = panel.frame.height
        let x = min(max(anchor.midX - w / 2, sf.minX + 4), sf.maxX - w - 4)
        let y = min(anchor.maxY + 2, sf.maxY - topInset - h)
        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }
}

final class ShelfItemView: NSView, NSDraggingSource {
    let url: URL
    var onGone: ((URL) -> Void)?

    init(url: URL, frame: NSRect) {
        self.url = url
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }

    private var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    override func draw(_ dirtyRect: NSRect) {
        icon.draw(in: NSRect(x: bounds.midX - 20, y: 24, width: 40, height: 40))
        let name = url.lastPathComponent as NSString
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byTruncatingMiddle
        name.draw(in: NSRect(x: 2, y: 4, width: bounds.width - 4, height: 14),
                  withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: clawdInk, .paragraphStyle: para])
    }

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(NSRect(x: bounds.midX - 20, y: 24, width: 40, height: 40), contents: icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }
    override func rightMouseDown(with event: NSEvent) { onGone?(url) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] { onGone?(url) }
    }
}

final class ShelfPanel {
    let panel: NSPanel
    var onChange: (([URL]) -> Void)?
    var urls: [URL] = []

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }

    var isVisible: Bool { panel.isVisible }
    func hide() { panel.orderOut(nil) }

    func set(_ new: [URL]) {
        urls = new
        let shown = Array(urls.prefix(7))
        let w = max(120, CGFloat(shown.count) * 66 + 16 + 26)
        let h: CGFloat = 92
        panel.setContentSize(NSSize(width: w, height: h))
        let bg = ShelfBackground(frame: NSRect(x: 0, y: 0, width: w, height: h))
        panel.contentView = bg
        for (i, u) in shown.enumerated() {
            let v = ShelfItemView(url: u, frame: NSRect(x: 8 + CGFloat(i) * 66, y: 10, width: 64, height: 72))
            v.onGone = { [weak self] gone in
                guard let self else { return }
                self.urls.removeAll { $0 == gone }
                self.set(self.urls)
                self.onChange?(self.urls)
            }
            bg.addSubview(v)
        }
        let clear = NSButton(frame: NSRect(x: w - 24, y: h - 26, width: 18, height: 18))
        clear.title = "✕"
        clear.isBordered = false
        clear.font = NSFont.systemFont(ofSize: 11)
        clear.target = self
        clear.action = #selector(clearAll)
        bg.addSubview(clear)
    }

    @objc func clearAll() {
        urls.removeAll()
        hide()
        onChange?(urls)
    }

    func show() {
        guard !urls.isEmpty else { return }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    func follow(anchor: NSRect, screenFrame sf: NSRect, topInset: CGFloat) {
        let w = panel.frame.width, h = panel.frame.height
        let x = min(max(anchor.midX - w / 2, sf.minX + 4), sf.maxX - w - 4)
        let y = min(anchor.maxY + 2, sf.maxY - topInset - h)
        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }
}

final class ShelfBackground: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        bubbleCream.setFill()
        path.fill()
        clawdOrange.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}

// MARK: - Calculator (safe recursive-descent parser: no NSExpression, which can crash on bad input)

struct MathParser {
    var s: [Character]
    var i = 0
    init(_ str: String) { s = Array(str.lowercased().replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
        .replacingOccurrences(of: ",", with: "")) }

    mutating func ws() { while i < s.count && s[i] == " " { i += 1 } }
    mutating func peek() -> Character? { ws(); return i < s.count ? s[i] : nil }

    mutating func parse() -> Double? {
        guard let v = expr() else { return nil }
        return peek() == nil ? v : nil
    }
    mutating func expr() -> Double? {
        guard var v = term() else { return nil }
        while let c = peek(), c == "+" || c == "-" {
            i += 1
            guard let r = term() else { return nil }
            v = c == "+" ? v + r : v - r
        }
        return v
    }
    mutating func term() -> Double? {
        guard var v = power() else { return nil }
        while let c = peek(), c == "*" || c == "/" || c == "x" {
            i += 1
            guard let r = power() else { return nil }
            v = c == "/" ? v / r : v * r
        }
        return v
    }
    mutating func power() -> Double? {
        guard let b = unary() else { return nil }
        if peek() == "^" { i += 1; guard let e = power() else { return nil }; return pow(b, e) }
        return b
    }
    mutating func unary() -> Double? {
        if peek() == "-" { i += 1; return unary().map { -$0 } }
        if peek() == "+" { i += 1; return unary() }
        return primary()
    }
    mutating func primary() -> Double? {
        guard let c = peek() else { return nil }
        if c == "(" {
            i += 1
            guard let v = expr(), peek() == ")" else { return nil }
            i += 1
            return v
        }
        if c.isNumber || c == "." {
            var str = ""
            while i < s.count, s[i].isNumber || s[i] == "." { str.append(s[i]); i += 1 }
            return Double(str)
        }
        if c.isLetter {
            var name = ""
            while i < s.count, s[i].isLetter { name.append(s[i]); i += 1 }
            if name == "pi" { return .pi }
            if name == "e" { return M_E }
            guard peek() == "(" else { return nil }
            i += 1
            guard let a = expr(), peek() == ")" else { return nil }
            i += 1
            switch name {
            case "sqrt": return a >= 0 ? sqrt(a) : nil
            case "sin": return sin(a)
            case "cos": return cos(a)
            case "tan": return tan(a)
            case "ln": return a > 0 ? log(a) : nil
            case "log": return a > 0 ? log10(a) : nil
            case "abs": return abs(a)
            case "round": return a.rounded()
            default: return nil
            }
        }
        return nil
    }
}

func formatNumber(_ v: Double) -> String {
    if v.isNaN || v.isInfinite { return "∞" }
    if v == v.rounded() && abs(v) < 1e15 { return String(Int(v)) }
    let f = NumberFormatter()
    f.maximumSignificantDigits = 10
    f.usesGroupingSeparator = false
    f.numberStyle = .decimal
    f.maximumFractionDigits = 10
    return f.string(from: NSNumber(value: v)) ?? "\(v)"
}

enum Calc {
    static let units: [String: Dimension] = [
        "mm": UnitLength.millimeters, "cm": UnitLength.centimeters, "m": UnitLength.meters, "km": UnitLength.kilometers,
        "in": UnitLength.inches, "inch": UnitLength.inches, "inches": UnitLength.inches,
        "ft": UnitLength.feet, "foot": UnitLength.feet, "feet": UnitLength.feet, "yd": UnitLength.yards, "mi": UnitLength.miles,
        "mile": UnitLength.miles, "miles": UnitLength.miles,
        "mg": UnitMass.milligrams, "g": UnitMass.grams, "kg": UnitMass.kilograms, "lb": UnitMass.pounds,
        "lbs": UnitMass.pounds, "oz": UnitMass.ounces,
        "c": UnitTemperature.celsius, "f": UnitTemperature.fahrenheit, "k": UnitTemperature.kelvin,
        "ml": UnitVolume.milliliters, "l": UnitVolume.liters, "gal": UnitVolume.gallons, "cup": UnitVolume.cups,
        "cups": UnitVolume.cups, "floz": UnitVolume.fluidOunces, "pt": UnitVolume.pints, "qt": UnitVolume.quarts,
        "mph": UnitSpeed.milesPerHour, "kph": UnitSpeed.kilometersPerHour, "kmh": UnitSpeed.kilometersPerHour,
        "mps": UnitSpeed.metersPerSecond, "kn": UnitSpeed.knots,
        "b": UnitInformationStorage.bytes, "kb": UnitInformationStorage.kilobytes, "mb": UnitInformationStorage.megabytes,
        "gb": UnitInformationStorage.gigabytes, "tb": UnitInformationStorage.terabytes,
        "s": UnitDuration.seconds, "min": UnitDuration.minutes, "h": UnitDuration.hours, "hr": UnitDuration.hours,
    ]
    static let symbols = ["$": "usd", "€": "eur", "£": "gbp", "¥": "jpy"]
    static var rates: [String: Double] = [:]
    static var ratesAt = Date.distantPast

    static func match(_ pattern: String, _ s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (1..<m.numberOfRanges).map { String(s[Range(m.range(at: $0), in: s)!]) }
    }

    /// Returns (display text, text to copy) via the completion; currency needs the network, the rest is instant.
    static func answer(_ raw: String, done: @escaping ((String, String)?) -> Void) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let clean = q.replacingOccurrences(of: ",", with: "")
        guard !q.isEmpty else { return done(nil) }

        if let g = match(#"^([\d.]+)\s*%\s*(of|off|on)\s+([\d.]+)$"#, clean), let p = Double(g[0]), let v = Double(g[2]) {
            let r = g[1] == "of" ? v * p / 100 : (g[1] == "off" ? v * (1 - p / 100) : v * (1 + p / 100))
            return done(("\(g[0])% \(g[1]) \(g[2]) = \(formatNumber(r))", formatNumber(r)))
        }

        if let g = match(#"^time in (.+)$"#, q) {
            let city = g[0].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "_")
            if let id = TimeZone.knownTimeZoneIdentifiers.first(where: { $0.lowercased().hasSuffix("/" + city) }),
               let tz = TimeZone(identifier: id) {
                let f = DateFormatter()
                f.timeZone = tz
                f.dateFormat = "EEE h:mm a"
                let t = f.string(from: Date())
                return done(("\(g[0].capitalized): \(t)", t))
            }
            return done(nil)
        }

        if let g = match(#"^(-?[\d.]+)\s*([a-z$€£¥]+)\s+(?:to|in|into)\s+([a-z]+)$"#, clean), let v = Double(g[0]) {
            if let a = units[g[1]], let b = units[g[2]] {
                guard type(of: a) == type(of: b) else { return done(nil) }
                let r = Measurement(value: v, unit: a).converted(to: b).value
                return done(("\(g[0]) \(g[1]) = \(formatNumber(r)) \(g[2])", formatNumber(r)))
            }
            let from = symbols[g[1]] ?? g[1], to = g[2]
            if from.count == 3 && to.count == 3 { return currency(v, from, to, done: done) }
            return done(nil)
        }
        if let g = match(#"^([€£$¥])\s*([\d.]+)\s+(?:to|in|into)\s+([a-z]{3})$"#, clean), let v = Double(g[1]) {
            return currency(v, symbols[g[0]] ?? "usd", g[2], done: done)
        }

        var p = MathParser(q)
        if let v = p.parse() { return done(("\(q) = \(formatNumber(v))", formatNumber(v))) }
        done(nil)
    }

    static func currency(_ v: Double, _ from: String, _ to: String, done: @escaping ((String, String)?) -> Void) {
        func finish() {
            guard let a = rates[from.uppercased()], let b = rates[to.uppercased()], a > 0 else { return done(nil) }
            let r = v / a * b
            done(("\(formatNumber(v)) \(from.uppercased()) = \(String(format: "%.2f", r)) \(to.uppercased())", String(format: "%.2f", r)))
        }
        if Date().timeIntervalSince(ratesAt) < 3600 && !rates.isEmpty { return finish() }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return done(nil) }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let r = j["rates"] as? [String: Double] {
                    rates = r
                    ratesAt = Date()
                }
                finish()
            }
        }.resume()
    }
}

// MARK: - File helpers

enum Files {
    static func unique(_ dir: URL, _ base: String, _ ext: String) -> URL {
        var u = dir.appendingPathComponent(ext.isEmpty ? base : "\(base).\(ext)")
        var i = 2
        while FileManager.default.fileExists(atPath: u.path) {
            u = dir.appendingPathComponent(ext.isEmpty ? "\(base) \(i)" : "\(base) \(i).\(ext)")
            i += 1
        }
        return u
    }

    static func size(_ u: URL) -> Int { (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 }

    static func human(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// Re-encodes an image (optionally downscaled). Returns the new file, or nil if it isn't an image.
    static func reencode(_ src: URL, type: String, ext: String, quality: Double, maxPixel: Int?, suffix: String) -> URL? {
        guard let source = CGImageSourceCreateWithURL(src as CFURL, nil) else { return nil }
        var cg: CGImage?
        if let mp = maxPixel {
            cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: mp] as CFDictionary)
        } else {
            cg = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        guard var image = cg else { return nil }
        if type == "public.jpeg" {   // flatten transparency onto white so it doesn't go black
            let cs = CGColorSpaceCreateDeviceRGB()
            if let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
                ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                if let flat = ctx.makeImage() { image = flat }
            }
        }
        let out = unique(src.deletingLastPathComponent(), src.deletingPathExtension().lastPathComponent + suffix, ext)
        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, type as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out : nil
    }

    static func zip(_ urls: [URL]) -> URL? {
        guard let first = urls.first else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("clawd-zip-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        do { try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true) } catch { return nil }
        for u in urls {
            let link = unique(tmp, u.lastPathComponent, "")
            try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: u)
        }
        let base = urls.count == 1 ? first.deletingPathExtension().lastPathComponent : "Archive"
        let out = unique(first.deletingLastPathComponent(), base, "zip")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.currentDirectoryURL = tmp
        p.arguments = ["-r", "-q", out.path, "."]
        guard (try? p.run()) != nil else { return nil }
        p.waitUntilExit()
        return p.terminationStatus == 0 ? out : nil
    }
}

// MARK: - Token Catch mini-game pieces

enum TokenKind { case coin, bug, gem }

final class TokenView: NSView {
    var kind = TokenKind.coin { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.shouldAntialias = false
        let u: CGFloat = 4
        func px(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: NSColor) {
            c.setFill()
            NSRect(x: CGFloat(x) * u, y: CGFloat(y) * u, width: CGFloat(w) * u, height: CGFloat(h) * u).fill()
        }
        switch kind {
        case .coin:
            let gold = rgb(0.96, 0.76, 0.18)
            px(1, 0, 3, 5, gold); px(0, 1, 5, 3, gold)
            px(1, 3, 1, 1, rgb(1, 0.93, 0.55)); px(2, 2, 1, 1, rgb(0.8, 0.55, 0.1))
        case .gem:
            let c = rgb(0.35, 0.8, 0.95)
            px(2, 0, 1, 1, c); px(1, 1, 3, 1, c); px(0, 2, 5, 1, c); px(1, 3, 3, 1, c); px(2, 4, 1, 1, c)
            px(1, 2, 1, 1, .white)
        case .bug:
            let g = rgb(0.3, 0.62, 0.25)
            px(1, 1, 3, 3, g); px(1, 4, 1, 1, g); px(3, 4, 1, 1, g)
            for (x, y) in [(0, 1), (4, 1), (0, 3), (4, 3)] { px(x, y, 1, 1, g) }
            px(1, 2, 1, 1, rgb(0.85, 0.15, 0.15)); px(3, 2, 1, 1, rgb(0.85, 0.15, 0.15))
        }
    }
}

final class TokenPanel: NSPanel {
    let tokenView = TokenView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 20, height: 20), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        contentView = tokenView
    }
    override var canBecomeKey: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

struct Token { var panel: TokenPanel; var kind: TokenKind; var x: CGFloat; var y: CGFloat; var vy: CGFloat }

// MARK: - The pet

let sayNotification = Notification.Name("com.randomclaudething.clawd.say")

final class Pet: NSObject, NSApplicationDelegate, NSMenuDelegate {
    enum Mode { case desk, dragging, falling, hopping, docking, docked, game }

    static let size = NSSize(width: 96, height: 88)
    static let toggleDefaults: [String: Bool] = [
        "nudges": true, "battery": true, "claude": true, "calendar": false,
        "climb": true, "sounds": true, "quiet": false, "clipboard": false,
    ]

    var mode = Mode.desk
    let brain = Brain()
    let bubble = Bubble()
    var panel: SpritePanel!
    var view: SpriteView!
    var statusItem: NSStatusItem?
    var timer: Timer?
    var last = CACurrentMediaTime()

    var x: CGFloat = 200
    var y: CGFloat = 0
    var vy: CGFloat = 0
    var squashT = 0.0
    var speakIn = 6.0
    var dragT = 0.0
    var inZone = false
    var dockT = 0.0
    var dockFrom = CGPoint.zero
    var titleClearAt = 0.0
    var lastZ = -1
    var iconCache: [Pose: NSImage] = [:]
    var lastIconPose: Pose?
    var pendingAlert: String?
    var redockAt: Double?
    var lastWall = 0.0

    // timers, reminders, nudges
    var reminders: [(fire: Date, text: String)] = []
    var focusEnd: Date?
    var focusTotal = 1500.0
    var focusIsBreak = false
    var nextNudge = Date().addingTimeInterval(.random(in: 2400...3300))

    // battery / power
    var lastBattery = 0.0
    var batteryWarned = false
    var wasOnBattery: Bool?

    // claude code watcher
    var lastPoll = 0.0
    var claudeCPU = 0.0
    var claudeWorking = false
    var workStart = 0.0
    var lowSince: Double?
    var lastWorkSay = 0.0

    // away / meeting
    var userIdle = false
    var inMeeting = false

    // perching on windows
    struct Perch { var id: Int; var rect: CGRect }
    var perch: Perch?
    var hopFrom = CGPoint.zero
    var hopTo = CGPoint.zero
    var hopT = 0.0
    var hopDur = 1.0
    var hopTarget: Perch?
    var nextPerch = CACurrentMediaTime() + 40
    var perchLeaveAt = 0.0

    // calendar / clipboard / notes
    let store = EKEventStore()
    var lastCal = 0.0
    var alertedEvents = Set<String>()
    var clipboard: [String] = []
    var pbCount = NSPasteboard.general.changeCount
    var notes: [String] = UserDefaults.standard.stringArray(forKey: "notes") ?? []

    // drop tray + shelf
    let tray = DropTray()
    let shelf = ShelfPanel()
    var trayUp = false
    var trayHideAt: Double?
    var shelfHideAt = 0.0

    // token catch
    var tokens: [Token] = []
    var tokenPool: [TokenPanel] = []
    var gameT = 0.0
    var score = 0
    var spawnIn = 0.0
    var hudIn = 0.0
    var gameFlash = 0.0
    var gameGood = true
    var pendingGame = false

    func on(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? Pet.toggleDefaults[key] ?? false
    }
    var isQuiet: Bool { on("quiet") || inMeeting }

    var screen: NSScreen {
        let c = CGPoint(x: x + Pet.size.width / 2, y: y + Pet.size.height / 2)
        return NSScreen.screens.first { $0.frame.contains(c) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
    var floorY: CGFloat { screen.visibleFrame.minY - 4 }
    var groundY: CGFloat { perch.map { $0.rect.maxY - 4 } ?? floorY }
    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    // MARK: launch

    func applicationDidFinishLaunching(_ n: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }

        panel = SpritePanel(contentRect: NSRect(origin: .zero, size: Pet.size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        view = SpriteView(frame: NSRect(origin: .zero, size: Pet.size))
        panel.contentView = view

        view.menuProvider = { [unowned self] in self.buildMenu(docked: false) }
        view.onDragStart = { [unowned self] in self.dragStarted() }
        view.onDragMove = { [unowned self] in self.dragMoved() }
        view.onDragEnd = { [unowned self] in self.dragEnded() }
        view.onClick = { [unowned self] in self.poked() }
        view.onHold = { [unowned self] in self.petted() }
        brain.onStart = { [unowned self] a in self.react(to: a) }
        view.onDragEnter = { [unowned self] in self.trayEnter() }
        view.onDragLeave = { [unowned self] in self.trayHideAt = CACurrentMediaTime() + 1.0 }
        view.onDrop = { [unowned self] urls, text in self.droppedOnClawd(urls, text) }
        for t in tray.tiles {
            t.onEnter = { [unowned self] in self.trayHideAt = nil }
            t.onExit = { [unowned self] in self.trayHideAt = CACurrentMediaTime() + 1.0 }
            t.onDrop = { [unowned self] kind, urls in self.runTile(kind, urls) }
        }
        shelf.onChange = { [unowned self] urls in
            if urls.isEmpty { self.shelf.hide() } else { self.shelfHideAt = CACurrentMediaTime() + 10 }
        }

        // `Clawd --say "text"` (e.g. from a Claude Code hook or a build script) lands here
        DistributedNotificationCenter.default().addObserver(forName: sayNotification, object: nil, queue: .main) { [weak self] n in
            guard let text = n.userInfo?["text"] as? String, !text.isEmpty else { return }
            self?.alert(text, sound: "Pop")
        }
        registerHotKey()
        if on("calendar") { enableCalendar() }

        let vis = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        x = .random(in: vis.minX + 40...max(vis.minX + 41, vis.maxX - 140))
        y = (NSScreen.main ?? NSScreen.screens[0]).frame.maxY

        if UserDefaults.standard.bool(forKey: "docked") {
            makeStatusItem()
            mode = .docked
            brain.start(.idle)
            setRate(12)
            verifyDocked(after: 1.5)
        } else {
            mode = .falling
            brain.start(.idle, dur: 1)
            panel.setFrameOrigin(CGPoint(x: x, y: y))
            panel.orderFrontRegardless()
            setRate(30)
            if !UserDefaults.standard.bool(forKey: "greeted") {
                UserDefaults.standard.set(true, forKey: "greeted")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                    self?.say("Hi! I'm Clawd. Drag me up to the menu bar and I'll live there.", hold: 6)
                }
            }
        }
    }

    func setRate(_ hz: Double) {
        timer?.invalidate()
        let t = Timer(timeInterval: 1 / hz, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        last = CACurrentMediaTime()
    }

    // MARK: speech

    func say(_ text: String, hold: Double = 3.2, typewriter: Bool = true) {
        switch mode {
        case .docked: setTitle(text, hold: hold)
        case .docking: break
        default: bubble.show(text, hold: hold, typewriter: typewriter)
        }
    }

    func chirp() {
        guard on("sounds"), let s = NSSound(named: NSSound.Name("Tink")) else { return }
        s.volume = 0.15
        s.play()
    }

    func setTitle(_ s: String, hold: Double) {
        var s = s
        if s.count > 26 { s = String(s.prefix(25)) + "…" }
        statusItem?.button?.title = " " + s
        titleClearAt = CACurrentMediaTime() + hold + 1
        // On notch Macs a wider item can get pushed under the notch: drop the text if so.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.mode == .docked, self.hiddenByNotch() else { return }
            self.statusItem?.button?.title = ""
            self.titleClearAt = 0
        }
    }

    /// True when the status item has no visible spot (pushed under the notch / off the bar).
    func hiddenByNotch() -> Bool {
        guard statusItem != nil else { return false }
        guard let w = statusItem?.button?.window, w.frame.width > 0 else { return true }
        if !w.isVisible || !w.occlusionState.contains(.visible) { return true }
        guard let scr = w.screen ?? NSScreen.main else { return true }
        if w.frame.maxY < scr.frame.maxY - 60 { return true }
        if scr.safeAreaInsets.top > 0, let r = scr.auxiliaryTopRightArea, w.frame.minX < r.minX { return true }
        return false
    }

    /// If macOS gave the status item no room, send Clawd back out instead of losing him.
    func verifyDocked(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.mode == .docked, self.hiddenByNotch() else { return }
            self.pendingAlert = "No room in the menu bar for me! Cmd-drag a few icons off it, then dock me again."
            self.undock()
        }
    }

    func react(to a: Act) {
        guard (mode == .desk || mode == .docked), !isQuiet else { return }
        switch a {
        case .think: say(Words.spinnerLine())
        case .wave: say(Words.greetings.randomElement()!, hold: 1.6)
        case .jump: if Int.random(in: 0..<10) < 4 { say(Words.hops.randomElement()!, hold: 1) }
        case .dance: say("♪ ♫ ♪", hold: 2)
        case .sleep: lastZ = -1
        default: break
        }
    }

    // MARK: dragging & touching

    func dragStarted() {
        if mode == .game { endGame(early: true) }
        mode = .dragging
        inZone = false
        dragT = 0
        redockAt = nil
        perch = nil
        bubble.show("Whoa!", hold: 1.2)
    }

    func dragMoved() {
        let m = NSEvent.mouseLocation
        let scr = NSScreen.screens.first { $0.frame.contains(m) } ?? NSScreen.main ?? NSScreen.screens[0]
        let zone = m.y > scr.frame.maxY - max(46, scr.safeAreaInsets.top + 24)
        if zone != inZone {
            inZone = zone
            if zone { bubble.show("The menu bar? Let go!", hold: 60) } else { bubble.hide() }
        }
    }

    func dragEnded() {
        x = panel.frame.origin.x
        y = panel.frame.origin.y
        if inZone {
            inZone = false
            dock()
        } else {
            bubble.hide()
            vy = 0
            mode = .falling
        }
    }

    func poked() {
        if mode == .game { return }
        if !shelf.urls.isEmpty && !shelf.isVisible {
            shelfHideAt = CACurrentMediaTime() + 10
            shelf.show()
            say("Holding \(shelf.urls.count) file\(shelf.urls.count == 1 ? "" : "s"). Drag them out!", hold: 3)
            return
        }
        brain.start(.jump)
        chirp()
        say(Bool.random() ? "Hehe!" : Words.random(short: false))
    }

    func petted() {
        guard mode == .desk else { return }
        brain.start(.wave)
        say(["♥", "♥ ♥", "*purrs*", "*happy crab noises*", "Aww."].randomElement()!, hold: 2.2, typewriter: false)
    }

    // MARK: docking into the menu bar

    func makeStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imagePosition = .imageLeft
        item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        item.button?.image = icon(Pose())
        item.menu = buildMenu(docked: true)
        statusItem = item
        lastIconPose = nil
    }

    func icon(_ p: Pose) -> NSImage {
        var p = p
        p.hat = .none
        if let i = iconCache[p] { return i }
        let i = spriteImage(p, unit: 1.5)
        iconCache[p] = i
        return i
    }

    func statusCenter() -> CGPoint {
        if let f = statusItem?.button?.window?.frame, f.width > 0, f.maxY > 100 {
            return CGPoint(x: f.midX, y: f.midY)
        }
        let f = screen.frame
        return CGPoint(x: f.maxX - 140, y: f.maxY - 12)
    }

    func dock() {
        guard mode == .desk || mode == .dragging || mode == .falling else { return }
        bubble.hide()
        perch = nil
        makeStatusItem()
        dockFrom = CGPoint(x: x + Pet.size.width / 2, y: y + Pet.size.height / 2)
        dockT = 0
        mode = .docking
        UserDefaults.standard.set(true, forKey: "docked")
    }

    @objc func undock() {
        guard mode == .docked else { return }
        let c = statusCenter()
        let scr = NSScreen.screens.first { $0.frame.contains(c) } ?? NSScreen.main ?? NSScreen.screens[0]
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
        UserDefaults.standard.set(false, forKey: "docked")
        x = min(max(c.x - Pet.size.width / 2, scr.visibleFrame.minX), scr.visibleFrame.maxX - Pet.size.width)
        y = scr.frame.maxY - Pet.size.height
        vy = 0
        view.scale = 1
        panel.alphaValue = 1
        panel.setFrameOrigin(CGPoint(x: x, y: y))
        panel.orderFrontRegardless()
        mode = .falling
        setRate(30)
        brain.start(.idle, dur: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            if let a = self.pendingAlert {
                self.pendingAlert = nil
                self.say(a, hold: 9)
            } else {
                self.say("Fresh air!", hold: 1.6)
            }
        }
    }

    // MARK: menus

    func buildMenu(docked: Bool) -> NSMenu {
        let m = NSMenu()
        m.delegate = self
        @discardableResult
        func add(_ title: String, _ sel: Selector, to menu: NSMenu? = nil, tag: Int = 0, obj: Any? = nil) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            i.target = self
            i.tag = tag
            i.representedObject = obj
            (menu ?? m).addItem(i)
            return i
        }
        func sub(_ title: String, _ menu: NSMenu) {
            let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            i.submenu = menu
            m.addItem(i)
        }
        for tag in [99, 98] {
            let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            status.tag = tag
            status.isEnabled = false
            m.addItem(status)
        }
        m.addItem(.separator())

        let focus = NSMenu()
        add("Focus 25 min", #selector(startTimer(_:)), to: focus, tag: 25, obj: "focus")
        add("Focus 50 min", #selector(startTimer(_:)), to: focus, tag: 50, obj: "focus")
        add("Break 5 min", #selector(startTimer(_:)), to: focus, tag: 5, obj: "break")
        add("Break 15 min", #selector(startTimer(_:)), to: focus, tag: 15, obj: "break")
        focus.addItem(.separator())
        add("Stop timer", #selector(stopTimer), to: focus)
        sub("Focus timer", focus)

        let rem = NSMenu()
        for mins in [5, 15, 30, 60] {
            add(mins == 60 ? "In 1 hour" : "In \(mins) minutes", #selector(quickReminder(_:)), to: rem, tag: mins)
        }
        rem.addItem(.separator())
        add("Custom…", #selector(customReminder), to: rem)
        sub("Remind me", rem)

        let notesMenu = NSMenu(title: "Notes")
        notesMenu.delegate = self
        sub("Notes", notesMenu)
        let clip = NSMenu(title: "Clipboard")
        clip.delegate = self
        sub("Clipboard history", clip)

        m.addItem(.separator())
        add("Pick a color   ⌃⌥C", #selector(pickColor))
        add("Ask Clawd: calc, convert…   ⌃⌥Space", #selector(askClawd))
        let pw = NSMenu()
        add("Strong · 20 characters", #selector(makePassword(_:)), to: pw, tag: 20)
        add("Long · 32 characters", #selector(makePassword(_:)), to: pw, tag: 32)
        add("Short · 12 characters", #selector(makePassword(_:)), to: pw, tag: 12)
        add("PIN · 6 digits", #selector(makePassword(_:)), to: pw, tag: -6)
        sub("Generate password   ⌃⌥P", pw)
        let sh = NSMenu()
        add("Show shelf", #selector(showShelf), to: sh)
        add("Clear shelf", #selector(clearShelf), to: sh)
        sub("File shelf", sh)

        m.addItem(.separator())
        let feats = NSMenu()
        for (title, key) in [("Break nudges (water, stretch)", "nudges"), ("Low battery warnings", "battery"),
                             ("Watch Claude Code", "claude"), ("Calendar heads-up", "calendar"),
                             ("Climb on windows", "climb"), ("Sounds", "sounds"), ("Quiet mode", "quiet")] {
            add(title, #selector(toggleDefault(_:)), to: feats, obj: key)
        }
        sub("Features", feats)
        let outfit = NSMenu()
        for (title, key) in [("Auto (seasonal)", "auto"), ("None", "none"), ("Party hat", "party"), ("Santa hat", "santa"),
                             ("Wizard hat", "wizard"), ("Crown", "crown"), ("Pumpkin", "pumpkin")] {
            add(title, #selector(setOutfit(_:)), to: outfit, obj: key)
        }
        sub("Outfit", outfit)

        m.addItem(.separator())
        if docked { add("Let Clawd out", #selector(undock)) } else { add("Move into menu bar", #selector(menuDock)) }
        add("Say something", #selector(chat))
        add("Dance!", #selector(danceNow))
        add(mode == .game ? "Stop game" : "Play: Token Catch", #selector(toggleGame))
        if !docked { add("Climb a window", #selector(climbNow)) }
        m.addItem(.separator())
        add("Launch at login", #selector(toggleLogin))
        add("Quit Clawd", #selector(quit))
        return m
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu.title == "Notes" {
            menu.removeAllItems()
            let n = NSMenuItem(title: "New note…  ⌃⌥N", action: #selector(newNote), keyEquivalent: "")
            n.target = self
            menu.addItem(n)
            menu.addItem(.separator())
            if notes.isEmpty {
                let e = NSMenuItem(title: "No notes yet", action: nil, keyEquivalent: "")
                e.isEnabled = false
                menu.addItem(e)
            }
            for (i, note) in notes.prefix(8).enumerated() {
                let it = NSMenuItem(title: oneLine(note), action: #selector(copyNote(_:)), keyEquivalent: "")
                it.target = self
                it.tag = i
                menu.addItem(it)
            }
            if !notes.isEmpty {
                menu.addItem(.separator())
                let c = NSMenuItem(title: "Clear all notes", action: #selector(clearNotes), keyEquivalent: "")
                c.target = self
                menu.addItem(c)
            }
            return
        }
        if menu.title == "Clipboard" {
            menu.removeAllItems()
            let t = NSMenuItem(title: "Keep history (in memory only)", action: #selector(toggleDefault(_:)), keyEquivalent: "")
            t.target = self
            t.representedObject = "clipboard"
            t.state = on("clipboard") ? .on : .off
            menu.addItem(t)
            menu.addItem(.separator())
            if clipboard.isEmpty {
                let e = NSMenuItem(title: on("clipboard") ? "Nothing copied yet" : "Off", action: nil, keyEquivalent: "")
                e.isEnabled = false
                menu.addItem(e)
            }
            for (i, c) in clipboard.enumerated() {
                let it = NSMenuItem(title: oneLine(c), action: #selector(copyClip(_:)), keyEquivalent: "")
                it.target = self
                it.tag = i
                menu.addItem(it)
            }
            return
        }
        for item in menu.items {
            if item.action == #selector(toggleLogin) { item.state = loginEnabled ? .on : .off }
            if item.action == #selector(toggleDefault(_:)), let k = item.representedObject as? String {
                item.state = on(k) ? .on : .off
            }
            if item.action == #selector(setOutfit(_:)), let k = item.representedObject as? String {
                item.state = (UserDefaults.standard.string(forKey: "outfit") ?? "auto") == k ? .on : .off
            }
            if item.tag == 99 {
                var lines: [String] = []
                if let end = focusEnd { lines.append("\(focusIsBreak ? "Break" : "Focus"): \(clock(end)) left") }
                if let r = reminders.min(by: { $0.fire < $1.fire }) {
                    lines.append("Next reminder in \(max(1, Int(r.fire.timeIntervalSinceNow / 60) + 1)) min")
                }
                if claudeWorking { lines.append("Claude Code is working") }
                item.title = lines.isEmpty ? "Nothing scheduled" : lines.joined(separator: " · ")
            }
            if item.tag == 98 { item.title = statsLine() }
        }
    }

    func oneLine(_ s: String) -> String {
        let t = s.replacingOccurrences(of: "\n", with: " ")
        return t.count > 48 ? String(t.prefix(47)) + "…" : t
    }

    @objc func menuDock() { redockAt = nil; if mode == .desk { dock() } }
    @objc func chat() { say(Words.random(short: mode == .docked)) }
    @objc func danceNow() { brain.start(.dance) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func toggleLogin() {
        do {
            if loginEnabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch {
            say("Couldn't change the login item.")
        }
    }

    @objc func toggleDefault(_ item: NSMenuItem) {
        guard let k = item.representedObject as? String else { return }
        UserDefaults.standard.set(!on(k), forKey: k)
        if k == "calendar" && on(k) { enableCalendar() }
        if k == "clipboard" && !on(k) { clipboard.removeAll() }
    }

    @objc func setOutfit(_ item: NSMenuItem) {
        UserDefaults.standard.set(item.representedObject as? String ?? "auto", forKey: "outfit")
        iconCache.removeAll()
    }

    func currentHat() -> Hat {
        let o = UserDefaults.standard.string(forKey: "outfit") ?? "auto"
        if o != "auto" { return Hat(rawValue: o) ?? .none }
        let c = Calendar.current.dateComponents([.month, .day], from: Date())
        if c.month == 12 { return .santa }
        if c.month == 10 && (c.day ?? 0) >= 15 { return .pumpkin }
        return .none
    }

    // MARK: stats

    func bump(_ key: String, by v: Double) {
        let d = UserDefaults.standard
        let day = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if d.string(forKey: "statsDay") != day {
            d.set(day, forKey: "statsDay")
            for k in ["claudeSecs", "claudeRuns", "focusDone"] { d.set(0.0, forKey: k) }
        }
        d.set(d.double(forKey: key) + v, forKey: key)
    }

    func statsLine() -> String {
        let d = UserDefaults.standard
        let day = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        guard d.string(forKey: "statsDay") == day else { return "Today: nothing yet" }
        let mins = Int(d.double(forKey: "claudeSecs") / 60)
        return "Today: Claude worked \(mins / 60)h \(mins % 60)m · \(Int(d.double(forKey: "claudeRuns"))) runs · \(Int(d.double(forKey: "focusDone"))) focus"
    }

    // MARK: timer (Clawd turns into a timer while it runs)

    func clock(_ end: Date) -> String {
        let s = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    func timerFace() -> (digits: Int, bar: Int, secs: Bool)? {
        guard let end = focusEnd else { return nil }
        let rem = max(0, end.timeIntervalSinceNow)
        let secs = rem < 60
        let digits = secs ? Int(rem.rounded(.up)) : Int((rem / 60).rounded(.up))
        let bar = Int((rem / focusTotal * 9).rounded(.up))
        return (min(99, digits), min(9, max(0, bar)), secs)
    }

    func focusTitle() -> String {
        guard let end = focusEnd else { return "" }
        return " " + clock(end)
    }

    @objc func startTimer(_ item: NSMenuItem) {
        focusIsBreak = (item.representedObject as? String) == "break"
        focusTotal = Double(item.tag) * 60
        focusEnd = Date().addingTimeInterval(focusTotal)
        lastIconPose = nil
        perch = nil
        updateOverride()
        say(focusIsBreak ? "Enjoy your break!" : "Focus mode: \(item.tag) min. I'll be quiet.", hold: 3)
    }

    @objc func stopTimer() {
        focusEnd = nil
        if mode == .docked { statusItem?.button?.title = "" }
        updateOverride()
        say("Timer stopped.", hold: 2)
    }

    func updateOverride() {
        let want: Act?
        if focusEnd != nil { want = .idle }
        else if userIdle { want = .sleep }
        else if claudeWorking && on("claude") { want = .work }
        else { want = nil }
        if brain.override != want { brain.override = want }
    }

    // MARK: reminders

    @objc func quickReminder(_ item: NSMenuItem) {
        reminders.append((Date().addingTimeInterval(Double(item.tag) * 60), "Time's up! ⏰"))
        say("Okay, I'll remind you in \(item.tag) min.", hold: 3)
    }

    @objc func customReminder() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Remind me…"
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 32, width: 240, height: 24))
        field.placeholderString = "what about?"
        let options = [("in 5 minutes", 5), ("in 15 minutes", 15), ("in 30 minutes", 30), ("in 1 hour", 60), ("in 2 hours", 120)]
        let pop = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 26))
        pop.addItems(withTitles: options.map { $0.0 })
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 60))
        box.addSubview(field)
        box.addSubview(pop)
        alert.accessoryView = box
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let mins = options[pop.indexOfSelectedItem].1
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        reminders.append((Date().addingTimeInterval(Double(mins) * 60), text.isEmpty ? "Time's up! ⏰" : text))
        say("Got it. See you in \(mins) min.", hold: 3)
    }

    // MARK: notes + clipboard + hotkey

    @objc func newNote() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Quick note"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "jot something down…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let t = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        notes.insert(t, at: 0)
        UserDefaults.standard.set(notes, forKey: "notes")
        say("Noted!", hold: 1.5)
    }

    @objc func copyNote(_ item: NSMenuItem) {
        guard notes.indices.contains(item.tag) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(notes[item.tag], forType: .string)
        pbCount = NSPasteboard.general.changeCount
        say("Copied the note.", hold: 1.5)
    }

    @objc func clearNotes() {
        notes.removeAll()
        UserDefaults.standard.removeObject(forKey: "notes")
    }

    @objc func copyClip(_ item: NSMenuItem) {
        guard clipboard.indices.contains(item.tag) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboard[item.tag], forType: .string)
        pbCount = NSPasteboard.general.changeCount
    }

    func pollClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != pbCount else { return }
        pbCount = pb.changeCount
        guard on("clipboard"),
              pb.types?.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) != true,
              let s = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return }
        clipboard.removeAll { $0 == s }
        clipboard.insert(s, at: 0)
        clipboard = Array(clipboard.prefix(10))
    }

    func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = Int(hk.id)
            DispatchQueue.main.async { (NSApp.delegate as? Pet)?.hotKey(id) }
            return noErr
        }, 1, &spec, nil, nil)
        let mods = UInt32(controlKey | optionKey)
        for (i, key) in [kVK_ANSI_N, kVK_ANSI_C, kVK_Space, kVK_ANSI_P].enumerated() {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(UInt32(key), mods, EventHotKeyID(signature: OSType(0x434C5744), id: UInt32(i + 1)),
                                GetApplicationEventTarget(), 0, &ref)
        }
    }

    func hotKey(_ id: Int) {
        switch id {
        case 1: newNote()
        case 2: pickColor()
        case 3: askClawd()
        default: generate(20)
        }
    }

    // MARK: tools: color picker, calculator, passwords

    @objc func pickColor() {
        NSColorSampler().show { [weak self] color in
            guard let self, let c = color?.usingColorSpace(.sRGB) else { return }
            let r = Int((c.redComponent * 255).rounded()), g = Int((c.greenComponent * 255).rounded()), b = Int((c.blueComponent * 255).rounded())
            let hex = String(format: "#%02X%02X%02X", r, g, b)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
            self.brain.start(.wave)
            self.say("\(hex) copied!  rgb(\(r), \(g), \(b))", hold: 4, typewriter: false)
        }
    }

    @objc func askClawd() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Ask Clawd"
        alert.informativeText = "Try: 15% of 240 · 5 ft in cm · 40 usd to eur · 72 f in c · (3+4)*2 · time in tokyo"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let q = field.stringValue
        Calc.answer(q) { [weak self] result in
            guard let self else { return }
            guard let (display, copy) = result else {
                self.say("Hmm, I can't work that one out.", hold: 3)
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copy, forType: .string)
            self.brain.start(.think)
            self.say(display + "  (copied)", hold: 8, typewriter: false)
        }
    }

    @objc func makePassword(_ item: NSMenuItem) { generate(item.tag) }

    func generate(_ n: Int) {
        let pw: String
        if n < 0 {
            pw = (0..<abs(n)).map { _ in String(Int.random(in: 0...9)) }.joined()
        } else {
            let sets = ["abcdefghijkmnopqrstuvwxyz", "ABCDEFGHJKLMNPQRSTUVWXYZ", "23456789", "!@#$%^&*-_=+"]
            var chars = sets.map { $0.randomElement()! }
            let all = sets.joined()
            while chars.count < n { chars.append(all.randomElement()!) }
            pw = String(chars.shuffled())
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(pw, forType: .string)
        pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pbCount = pb.changeCount
        let cc = pb.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { if pb.changeCount == cc { pb.clearContents() } }
        brain.start(.wave)
        say("\(pw)\ncopied, clears in 45s", hold: 12, typewriter: false)
    }

    // MARK: perching on demand + Token Catch

    @objc func climbNow() {
        guard mode == .desk else { return }
        guard let t = perchCandidates().randomElement() else {
            say("No windows to climb on.", hold: 2.5)
            return
        }
        perch = nil
        startHop(to: t)
    }

    @objc func toggleGame() {
        if mode == .game { endGame(early: true) } else { startGame() }
    }

    func startGame() {
        if mode == .docked {
            pendingGame = true
            undock()
            return
        }
        guard mode == .desk else { return }
        redockAt = nil
        perch = nil
        hideTray()
        shelf.hide()
        y = floorY
        gameT = 0
        score = 0
        spawnIn = 0.6
        hudIn = 0
        gameFlash = 0
        mode = .game
        bubble.show("Token Catch! Move your mouse to move me. Grab coins, dodge bugs.", hold: 3.5)
    }

    func spawnToken() {
        let vis = screen.visibleFrame
        let r = Double.random(in: 0..<100)
        let bugChance = min(38.0, 18 + gameT * 0.7)
        let kind: TokenKind = r < bugChance ? .bug : (r < bugChance + 6 ? .gem : .coin)
        let panel = tokenPool.popLast() ?? TokenPanel()
        panel.tokenView.kind = kind
        let tx = CGFloat.random(in: vis.minX + 10...(vis.maxX - 30))
        let ty = screen.frame.maxY - max(60, screen.safeAreaInsets.top + 30)
        panel.setFrameOrigin(CGPoint(x: tx, y: ty))
        panel.orderFrontRegardless()
        tokens.append(Token(panel: panel, kind: kind, x: tx, y: ty, vy: CGFloat(210 + gameT * 6 + Double.random(in: 0...80))))
    }

    func gameTick(_ dt: Double, now: Double) {
        gameT += dt
        let vis = screen.visibleFrame
        let target = NSEvent.mouseLocation.x - Pet.size.width / 2
        let old = x
        x += (target - x) * CGFloat(min(1, dt * 14))
        x = min(max(x, vis.minX - 8), vis.maxX - Pet.size.width + 8)
        y = floorY

        var p = Pose()
        p.legs = abs(x - old) > 0.8 ? Int(now / 0.08) % 2 + 1 : 0
        p.eyeShift = max(-1, min(1, Int((target - x) / 40)))
        if gameFlash > 0 {
            gameFlash -= dt
            p.eyes = gameGood ? .happy : .wide
            if gameGood { p.armL = 4; p.armR = 4 }
        }
        view.pose = p
        moveWindow()

        spawnIn -= dt
        if spawnIn <= 0 {
            spawnToken()
            spawnIn = max(0.28, 0.75 - gameT * 0.015)
        }

        let clawd = CGRect(x: x + 14, y: y + 4, width: Pet.size.width - 28, height: 56)
        var keep: [Token] = []
        for var t in tokens {
            t.y -= t.vy * CGFloat(dt)
            if CGRect(x: t.x, y: t.y, width: 20, height: 20).intersects(clawd) {
                switch t.kind {
                case .coin: score += 1; gameGood = true; gameSound("Tink")
                case .gem: score += 5; gameGood = true; gameSound("Glass")
                case .bug: score = max(0, score - 2); gameGood = false; gameSound("Funk")
                }
                gameFlash = 0.3
                t.panel.orderOut(nil)
                tokenPool.append(t.panel)
            } else if t.y < floorY - 20 {
                t.panel.orderOut(nil)
                tokenPool.append(t.panel)
            } else {
                t.panel.setFrameOrigin(CGPoint(x: t.x, y: t.y.rounded()))
                keep.append(t)
            }
        }
        tokens = keep

        hudIn -= dt
        if hudIn <= 0 {
            hudIn = 0.25
            bubble.show("Score \(score)   ·   \(max(0, 30 - Int(gameT)))s", hold: 0.7, typewriter: false)
        }
        if gameT >= 30 { endGame(early: false) }
    }

    func gameSound(_ name: String) {
        guard on("sounds"), let s = NSSound(named: NSSound.Name(name)) else { return }
        s.volume = 0.25
        s.play()
    }

    func endGame(early: Bool) {
        for t in tokens { t.panel.orderOut(nil); tokenPool.append(t.panel) }
        tokens.removeAll()
        mode = .desk
        let best = UserDefaults.standard.integer(forKey: "best")
        let newBest = score > best
        if newBest { UserDefaults.standard.set(score, forKey: "best") }
        brain.start(early ? .idle : .dance, dur: early ? 1 : 2.6)
        if early {
            say("Game over!", hold: 2)
        } else {
            say("Score: \(score)! " + (newBest ? "New best!" : "Best: \(best)"), hold: 5, typewriter: false)
        }
    }

    // MARK: drop tray + shelf

    func trayEnter() {
        guard mode == .desk else { return }
        trayUp = true
        trayHideAt = nil
        bubble.hide()
        shelf.hide()
        tray.show()
    }

    func hideTray() {
        trayUp = false
        trayHideAt = nil
        tray.hide()
    }

    func droppedOnClawd(_ urls: [URL], _ text: String?) -> Bool {
        hideTray()
        if !urls.isEmpty {
            runTile(.hold, urls)
            return true
        }
        if let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            notes.insert(t, at: 0)
            UserDefaults.standard.set(notes, forKey: "notes")
            say("Saved that as a note.", hold: 2)
            return true
        }
        return false
    }

    @objc func showShelf() {
        if shelf.urls.isEmpty { say("The shelf is empty. Drop files on me!", hold: 3); return }
        shelfHideAt = CACurrentMediaTime() + 15
        shelf.show()
    }
    @objc func clearShelf() { shelf.clearAll() }

    func runTile(_ kind: Tile, _ urls: [URL]) {
        hideTray()
        let n = urls.count
        let plural = n == 1 ? "" : "s"
        switch kind {
        case .hold:
            for u in urls where !shelf.urls.contains(u) { shelf.urls.append(u) }
            shelf.set(shelf.urls)
            shelfHideAt = CACurrentMediaTime() + 10
            shelf.show()
            brain.start(.wave)
            say("Holding \(shelf.urls.count) file\(shelf.urls.count == 1 ? "" : "s"). Drag them out whenever.", hold: 3)
        case .path:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(urls.map { $0.path }.joined(separator: "\n"), forType: .string)
            say("Copied \(n) path\(plural).", hold: 2.5)
        case .trash:
            NSWorkspace.shared.recycle(urls) { [weak self] _, error in
                DispatchQueue.main.async {
                    self?.say(error == nil ? "Moved \(n) item\(plural) to the Trash." : "Couldn't trash that.", hold: 2.5)
                }
            }
        case .png, .jpg, .shrink, .zip:
            say("On it…", hold: 1.5)
            DispatchQueue.global(qos: .userInitiated).async {
                let msg = Self.process(kind, urls)
                DispatchQueue.main.async {
                    self.brain.start(.jump)
                    self.say(msg, hold: 5)
                }
            }
        }
    }

    static func process(_ kind: Tile, _ urls: [URL]) -> String {
        if kind == .zip {
            guard let out = Files.zip(urls) else { return "Zip failed." }
            return "Made \(out.lastPathComponent) (\(Files.human(Files.size(out))))."
        }
        var done = 0, skipped = 0, before = 0, after = 0
        for u in urls {
            var out: URL?
            switch kind {
            case .png: out = Files.reencode(u, type: "public.png", ext: "png", quality: 1, maxPixel: nil, suffix: "")
            case .jpg: out = Files.reencode(u, type: "public.jpeg", ext: "jpg", quality: 0.9, maxPixel: nil, suffix: "")
            default:
                let isPNG = u.pathExtension.lowercased() == "png"
                out = isPNG
                    ? Files.reencode(u, type: "public.png", ext: "png", quality: 1, maxPixel: 1600, suffix: "-small")
                    : Files.reencode(u, type: "public.jpeg", ext: "jpg", quality: 0.7, maxPixel: 2000, suffix: "-small")
            }
            if let out {
                done += 1
                before += Files.size(u)
                after += Files.size(out)
                if kind == .shrink && Files.size(out) >= Files.size(u) {   // no gain: don't leave a bigger copy
                    try? FileManager.default.removeItem(at: out)
                    done -= 1
                    skipped += 1
                    before -= Files.size(u)
                    after -= Files.size(out)
                }
            } else {
                skipped += 1
            }
        }
        if done == 0 { return kind == .shrink && skipped > 0 ? "Those are already small, or not images." : "Those aren't images I can read." }
        var msg = kind == .shrink
            ? "Shrunk \(done) image\(done == 1 ? "" : "s"): \(Files.human(before)) → \(Files.human(after))."
            : "Converted \(done) image\(done == 1 ? "" : "s") next to the original."
        if skipped > 0 { msg += " Skipped \(skipped)." }
        return msg
    }

    // MARK: alerts

    /// Pops Clawd out of the menu bar if needed, then delivers the message; he goes back home afterwards.
    func alert(_ text: String, hold: Double = 9, sound: String? = "Glass") {
        if let sound { NSSound(named: NSSound.Name(sound))?.play() }
        switch mode {
        case .docked:
            pendingAlert = text
            redockAt = CACurrentMediaTime() + hold + 4
            undock()
        case .docking:
            pendingAlert = text
        default:
            if focusEnd == nil { brain.start(.jump) }
            say(text, hold: hold)
        }
    }

    // MARK: power, calendar, claude code, windows

    func batteryStatus() -> (percent: Int, onBattery: Bool)? {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(snap, ps)?.takeUnretainedValue() as? [String: Any],
                  let cur = d[kIOPSCurrentCapacityKey] as? Int, let cap = d[kIOPSMaxCapacityKey] as? Int, cap > 0,
                  let state = d[kIOPSPowerSourceStateKey] as? String else { continue }
            return (cur * 100 / cap, state == kIOPSBatteryPowerValue)
        }
        return nil
    }

    func enableCalendar() {
        store.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async {
                if !granted {
                    UserDefaults.standard.set(false, forKey: "calendar")
                    self.say("I need Calendar access (System Settings → Privacy) to warn you about events.", hold: 6)
                }
            }
        }
    }

    func checkCalendar() {
        guard on("calendar"), EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        let now = Date()
        let pred = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(11 * 60), calendars: nil)
        for e in store.events(matching: pred) where !e.isAllDay {
            let mins = e.startDate.timeIntervalSince(now) / 60
            let key = (e.eventIdentifier ?? e.title ?? "") + "\(e.startDate.timeIntervalSince1970)"
            if mins > 0 && mins <= 5.5 && !alertedEvents.contains(key) {
                alertedEvents.insert(key)
                alert("\(e.title ?? "Event") in \(Int(ceil(mins))) min", hold: 10)
            }
        }
    }

    func pollProcesses() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/ps")
            p.arguments = ["-axo", "pcpu=,command="]
            let pipe = Pipe()
            p.standardOutput = pipe
            guard (try? p.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            var cpu = 0.0
            var meeting = false
            for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
                guard parts.count == 2, let c = Double(parts[0]) else { continue }
                let cmd = String(parts[1])
                let exe = cmd.range(of: " --").map { String(cmd[..<$0.lowerBound]) } ?? cmd
                let name = (exe as NSString).lastPathComponent
                if name == "claude" || cmd.contains("@anthropic-ai/claude-code") { cpu += c }
                if name == "CptHost" { meeting = true }
            }
            DispatchQueue.main.async { self?.processUpdate(cpu: cpu, meeting: meeting) }
        }
    }

    func processUpdate(cpu: Double, meeting: Bool) {
        inMeeting = meeting
        guard on("claude") else {
            if claudeWorking { claudeWorking = false; updateOverride() }
            return
        }
        let now = CACurrentMediaTime()
        claudeCPU = claudeCPU * 0.4 + cpu * 0.6
        if claudeCPU > 10 {
            lowSince = nil
            if !claudeWorking {
                claudeWorking = true
                workStart = now
                lastWorkSay = 0
                updateOverride()
            }
        } else if claudeWorking {
            if lowSince == nil { lowSince = now }
            if now - (lowSince ?? now) >= 6 {
                claudeWorking = false
                lowSince = nil
                updateOverride()
                let dur = now - workStart - 6
                if dur >= 20 {
                    bump("claudeSecs", by: dur)
                    bump("claudeRuns", by: 1)
                    alert("Claude Code finished!", hold: 5, sound: "Pop")
                }
            }
        }
    }

    func windowRects() -> [Perch] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let H = NSScreen.screens[0].frame.height
        var out: [Perch] = []
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerName as String] as? String) != "Clawd",
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.5,
                  let id = w[kCGWindowNumber as String] as? Int,
                  let bd = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: bd) else { continue }
            out.append(Perch(id: id, rect: CGRect(x: r.minX, y: H - r.maxY, width: r.width, height: r.height)))
        }
        return out
    }

    /// Windows whose top edge is actually visible (not covered by a window in front) and big enough to stand on.
    func perchCandidates() -> [Perch] {
        let all = windowRects()
        var res: [Perch] = []
        for (i, w) in all.enumerated() {
            let r = w.rect
            guard r.width >= 260, r.height >= 160 else { continue }
            guard let scr = NSScreen.screens.first(where: { $0.frame.intersects(r) }) else { continue }
            guard r.maxY < scr.frame.maxY - max(40, scr.safeAreaInsets.top + 10), r.maxY > scr.visibleFrame.minY + 140 else { continue }
            let probe = CGPoint(x: r.midX, y: r.maxY - 3)
            if all[..<i].contains(where: { $0.rect.contains(probe) }) { continue }
            res.append(w)
        }
        return res
    }

    func startHop(to target: Perch) {
        let tx = CGFloat.random(in: (target.rect.minX + 4)...max(target.rect.minX + 5, target.rect.maxX - Pet.size.width - 4))
        hopFrom = CGPoint(x: x, y: y)
        hopTo = CGPoint(x: tx, y: target.rect.maxY - 4)
        hopTarget = target
        hopT = 0
        hopDur = 0.7 + Double(hypot(hopTo.x - x, hopTo.y - y)) / 1600
        mode = .hopping
    }

    func leavePerch() {
        perch = nil
        vy = 260
        mode = .falling
    }

    // MARK: periodic checks (about once a second)

    func checkUtilities() {
        let now = Date()
        let mono = CACurrentMediaTime()
        pollClipboard()

        // away detection: nap when you've been gone a while
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        if !userIdle && idle > 180 {
            userIdle = true
            updateOverride()
        } else if userIdle && idle < 5 {
            userIdle = false
            updateOverride()
            if mode == .desk && !isQuiet { brain.start(.wave); say("Oh, you're back!", hold: 2) }
        }

        if mono - lastPoll >= 3 { lastPoll = mono; pollProcesses() }

        if claudeWorking && !isQuiet && focusEnd == nil && mono - lastWorkSay >= 8 {
            lastWorkSay = mono
            say(Words.spinnerLine(), hold: 3.5)
        }

        if on("calendar"), mono - lastCal > 60 { lastCal = mono; checkCalendar() }

        if let i = reminders.firstIndex(where: { $0.fire <= now }) {
            alert(reminders.remove(at: i).text)
            return
        }

        if let end = focusEnd, end <= now {
            focusEnd = nil
            if mode == .docked { statusItem?.button?.title = "" }
            updateOverride()
            if focusIsBreak {
                alert("Break's over. Back to it!")
            } else {
                bump("focusDone", by: 1)
                alert("Focus session done! Take a 5 min break?")
            }
            return
        }

        if on("nudges") && now >= nextNudge {
            nextNudge = now.addingTimeInterval(.random(in: 2400...3300))
            if focusEnd == nil && !isQuiet {
                alert(["Drink some water!", "Stretch your legs!", "Look away from the screen for 20 seconds.",
                       "Posture check!", "Rest your eyes for a moment."].randomElement()!, hold: 7, sound: nil)
                return
            }
        }

        if mono - lastBattery > 20 {
            lastBattery = mono
            if let b = batteryStatus() {
                if let was = wasOnBattery, was, !b.onBattery, !isQuiet {
                    brain.start(.dance)
                    say("Power! Nom nom.", hold: 2.5)
                }
                wasOnBattery = b.onBattery
                if on("battery") {
                    if b.onBattery && b.percent <= 20 && !batteryWarned {
                        batteryWarned = true
                        alert("Battery at \(b.percent)%. Plug me in!", sound: "Basso")
                    } else if !b.onBattery || b.percent > 30 {
                        batteryWarned = false
                    }
                }
            }
        }

        // window perching
        if mode == .desk, let p = perch {
            if let cur = windowRects().first(where: { $0.id == p.id }), abs(cur.rect.maxY - p.rect.maxY) < 120 {
                x += cur.rect.minX - p.rect.minX     // ride along if the window is moved
                perch = cur
                if mono > perchLeaveAt || focusEnd != nil || !on("climb") { leavePerch() }
            } else {
                leavePerch()
            }
        } else if mode == .desk && perch == nil && on("climb") && focusEnd == nil && !claudeWorking && !userIdle && mono > nextPerch {
            nextPerch = mono + .random(in: 45...120)
            if let t = perchCandidates().randomElement() { startHop(to: t) }
        }
    }

    // MARK: tick

    func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - last, 0.1)
        last = now

        switch mode {
        case .desk:
            brain.update(dt)
            let vis = screen.visibleFrame
            let lo = (perch?.rect.minX ?? vis.minX) - 8
            let hi = (perch?.rect.maxX ?? vis.maxX) - Pet.size.width + 8
            x += trayUp ? 0 : brain.vx * CGFloat(dt)
            if x < lo { x = lo; brain.dir = 1 }
            if x > hi { x = hi; brain.dir = -1 }
            y = groundY + brain.jumpY
            var p = brain.pose
            if squashT > 0 { squashT -= dt; p.squash = true }

            let mouse = NSEvent.mouseLocation
            if brain.act == .chase {
                let c = x + Pet.size.width / 2
                if abs(mouse.x - c) < 50 {
                    brain.start(.look)
                    if !isQuiet { say("Gotcha!", hold: 1.2) }
                } else {
                    brain.dir = mouse.x > c ? 1 : -1
                }
            }
            if brain.act == .idle && brain.override == nil && (p.eyes == .open || p.eyes == .blink) {
                let dx = mouse.x - (x + Pet.size.width / 2)
                p.eyeShift = dx < -150 ? -1 : (dx > 150 ? 1 : 0)
                p.eyeLift = mouse.y - (y + 40) > 220 ? 1 : 0
            }
            if let f = timerFace() {
                p.timer = f.digits
                p.timerBar = f.bar
                p.timerSecs = f.secs
                p.timerBreak = focusIsBreak
                p.armL = Int(now) % 2
                p.eyes = .open
            }
            if trayUp { p.eyes = .happy; p.armL = 4; p.armR = 4 }
            view.pose = p
            moveWindow()
            ambientSpeech(dt)
            if let t = redockAt, now > t, !bubble.isVisible { redockAt = nil; dock() }
            sleepZs()

        case .dragging:
            dragT += dt
            x = panel.frame.origin.x
            y = panel.frame.origin.y
            var p = Pose()
            let s = Int(dragT / 0.14)
            p.legs = s % 2 == 0 ? 1 : 2
            if inZone {
                p.eyes = .happy
                p.armL = 5
                p.armR = 5
            } else {
                p.eyes = .wide
                p.armL = s % 2
                p.armR = (s + 1) % 2
            }
            view.pose = p

        case .falling:
            vy -= 2200 * CGFloat(dt)
            y += vy * CGFloat(dt)
            let vis = screen.visibleFrame
            x = min(max(x, vis.minX - 8), vis.maxX - Pet.size.width + 8)
            var p = Pose()
            p.eyes = .wide
            p.armL = 4
            p.armR = 4
            p.legs = Int(CACurrentMediaTime() / 0.12) % 2 + 1
            view.pose = p
            if y <= floorY {
                y = floorY
                if vy < -500 { squashT = 0.2 }
                if vy < -1100 { say("Oof.", hold: 1.2) }
                vy = 0
                mode = .desk
                brain.start(.idle, dur: 0.8)
                updateOverride()
                if pendingGame {
                    pendingGame = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.startGame() }
                }
            }
            moveWindow()

        case .game:
            gameTick(dt, now: now)

        case .hopping:
            hopT += dt
            let u = min(hopT / hopDur, 1)
            x = hopFrom.x + (hopTo.x - hopFrom.x) * CGFloat(u)
            y = hopFrom.y + (hopTo.y - hopFrom.y) * CGFloat(u) + 80 * CGFloat(4 * u * (1 - u))
            var p = Pose()
            p.eyes = .happy
            p.armL = 3
            p.armR = 3
            p.squash = u < 0.08 || u > 0.94
            view.pose = p
            moveWindow()
            if u >= 1, let t = hopTarget {
                perch = t
                perchLeaveAt = now + .random(in: 25...60)
                mode = .desk
                hopTarget = nil
                brain.start(.idle, dur: 1)
                if !isQuiet { say(["Nice view up here.", "King of the window!", "Don't mind me."].randomElement()!, hold: 2.5) }
            }

        case .docking:
            dockT += dt
            let p = min(dockT / 0.45, 1)
            let e = CGFloat(p * p * (3 - 2 * p))
            let to = statusCenter()
            let c = CGPoint(x: dockFrom.x + (to.x - dockFrom.x) * e, y: dockFrom.y + (to.y - dockFrom.y) * e)
            panel.setFrameOrigin(CGPoint(x: c.x - Pet.size.width / 2, y: c.y - Pet.size.height / 2))
            view.scale = 1 - 0.78 * e
            var pose = Pose()
            pose.eyes = .happy
            pose.armL = 5
            pose.armR = 5
            pose.legs = Int(dockT / 0.08) % 2 + 1
            view.pose = pose
            if p >= 1 {
                panel.orderOut(nil)
                view.scale = 1
                mode = .docked
                brain.start(.idle, dur: 1)
                setRate(12)
                updateOverride()
                setTitle("Home!", hold: 2)
                verifyDocked(after: 0.8)
            }

        case .docked:
            brain.update(dt)
            var p = brain.pose
            if brain.jumpY > 10 { p.bob = 1 }
            if let f = timerFace() {
                p.timer = f.digits
                p.timerBar = f.bar
                p.timerSecs = f.secs
                p.timerBreak = focusIsBreak
                p.armL = Int(now) % 2
            }
            if p != lastIconPose {
                lastIconPose = p
                statusItem?.button?.image = icon(p)
            }
            if titleClearAt > 0 && now > titleClearAt {
                statusItem?.button?.title = ""
                titleClearAt = 0
            }
            if titleClearAt == 0 {
                let t = focusTitle()
                if statusItem?.button?.title != t { statusItem?.button?.title = t }
            }
            speakIn -= dt
            if speakIn <= 0 && brain.act != .sleep {
                speakIn = .random(in: 14...30)
                if !isQuiet { say(Words.random(short: true)) }
            }
            sleepZs()
        }

        if mode != .docked && mode != .docking {
            var vp = view.pose
            let hat = currentHat()
            if vp.hat != hat { vp.hat = hat; view.pose = vp }
        }

        if trayUp {
            tray.follow(anchor: panel.frame, screenFrame: screen.frame, topInset: max(screen.safeAreaInsets.top, 24))
            if let t = trayHideAt, now > t { hideTray() }
        }
        if shelf.isVisible {
            shelf.follow(anchor: panel.frame, screenFrame: screen.frame, topInset: max(screen.safeAreaInsets.top, 24))
            if shelf.panel.frame.contains(NSEvent.mouseLocation) { shelfHideAt = max(shelfHideAt, now + 3) }
            if now > shelfHideAt { shelf.hide() }
        }

        if now - lastWall >= 1 {
            lastWall = now
            checkUtilities()
        }

        if mode != .docked && mode != .docking {
            bubble.update(anchor: panel.frame, screenFrame: screen.frame, topInset: max(screen.safeAreaInsets.top, 24), now: now)
        }
    }

    func moveWindow() {
        let o = CGPoint(x: x.rounded(), y: y.rounded())
        if panel.frame.origin != o { panel.setFrameOrigin(o) }
    }

    func ambientSpeech(_ dt: Double) {
        speakIn -= dt
        if speakIn <= 0 && brain.act != .sleep && !bubble.isVisible && !isQuiet && focusEnd == nil {
            speakIn = .random(in: 10...22)
            chirp()
            say(Words.random(short: false))
        } else if speakIn <= 0 {
            speakIn = 8
        }
    }

    func sleepZs() {
        guard brain.act == .sleep, !isQuiet else { return }
        let step = Int(brain.t / 1.2) % 3
        if step != lastZ {
            lastZ = step
            say(["z", "zZ", "zZz"][step], hold: 1.3, typewriter: false)
        }
    }
}

// MARK: - CLI helpers (used by build.sh for the app icon, and for previewing sprites / talking to a running Clawd)

let args = CommandLine.arguments

if args.count >= 3 && args[1] == "--say" {
    DistributedNotificationCenter.default().postNotificationName(sayNotification, object: nil,
                                                                 userInfo: ["text": args[2]], deliverImmediately: true)
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    exit(0)
}

if args.count >= 3 && args[1] == "--art" {
    renderArt(into: args[2])
    exit(0)
}

if args.count >= 3 && args[1] == "--calc" {
    Calc.answer(args[2]) { r in print(r?.0 ?? "nil"); exit(0) }
    RunLoop.main.run(until: Date().addingTimeInterval(8))
    exit(1)
}

if args.count >= 4 && args[1] == "--proc" {
    let kind: Tile = ["png": .png, "jpg": .jpg, "shrink": .shrink, "zip": .zip][args[2]] ?? .png
    print(Pet.process(kind, args[3...].map { URL(fileURLWithPath: $0) }))
    exit(0)
}

if args.count >= 3 && args[1] == "--sheet" {
    var poses: [Pose] = [
        Pose(), Pose(eyes: .blink), Pose(eyes: .happy, armR: 5), Pose(eyes: .happy, armL: 5, legs: 1, bob: 1),
        Pose(legs: 1, bob: 1), Pose(legs: 2), Pose(eyes: .sleep, squash: true),
        Pose(eyes: .wide, armL: 4, armR: 4, legs: 1), Pose(eyeShift: 1, eyeLift: 1, armR: 2),
    ]
    poses.append(Pose(timer: 24, timerBar: 6))
    poses.append(Pose(timer: 7, timerBar: 1, timerSecs: true, timerBreak: true))
    for h in [Hat.party, .santa, .wizard, .crown, .pumpkin] { poses.append(Pose(hat: h)) }
    let u: CGFloat = 8
    let cell = NSSize(width: CGFloat(canvasW + 2) * u, height: CGFloat(canvasH + 2) * u)
    let cols = 8
    let rows = (poses.count + cols - 1) / cols
    let img = NSImage(size: NSSize(width: cell.width * CGFloat(cols), height: cell.height * CGFloat(rows)), flipped: false) { r in
        NSColor(white: 0.95, alpha: 1).setFill()
        r.fill()
        NSGraphicsContext.current?.shouldAntialias = false
        for (i, p) in poses.enumerated() {
            let col = i % cols, row = i / cols
            drawClawd(p, unit: u, origin: CGPoint(x: cell.width * CGFloat(col) + u,
                                                  y: cell.height * CGFloat(rows - 1 - row) + u))
        }
        return true
    }
    writePNG(img, to: args[2])
    exit(0)
}

if args.count >= 3 && args[1] == "--icon" {
    let s: CGFloat = 1024
    let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
        let bg = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: s - 120, height: s - 120), xRadius: 200, yRadius: 200)
        NSColor(srgbRed: 0.94, green: 0.933, blue: 0.902, alpha: 1).setFill()
        bg.fill()
        NSGraphicsContext.current?.shouldAntialias = false
        let u: CGFloat = 40
        drawClawd(Pose(eyes: .open), unit: u,
                  origin: CGPoint(x: (s - CGFloat(canvasW) * u) / 2, y: (s - 11 * u) / 2))
        return true
    }
    writePNG(img, to: args[2])
    exit(0)
}

// MARK: - main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let pet = Pet()
app.delegate = pet
app.run()
