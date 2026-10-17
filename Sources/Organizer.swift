import Cocoa

// MARK: - Smart folder organiser (plan, perform, undo)

struct OrgMove { let src: URL; let folder: String }
struct OrgEntry: Codable { let from: String; let to: String }
struct OrgLog: Codable {
    var entries: [OrgEntry] = []
    var created: [String] = []
    var folder = ""
}

enum Organizer {
    static let categories: [(String, Set<String>)] = [
        ("Images", ["png", "jpg", "jpeg", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp", "svg", "raw", "cr2", "nef", "dng", "avif"]),
        ("Videos", ["mp4", "mov", "mkv", "avi", "webm", "m4v", "wmv", "flv"]),
        ("Audio", ["mp3", "m4a", "wav", "flac", "aac", "aiff", "ogg", "opus", "wma"]),
        ("Documents", ["pdf", "doc", "docx", "pages", "txt", "rtf", "md", "odt", "tex"]),
        ("Spreadsheets", ["xls", "xlsx", "numbers", "csv", "tsv", "ods"]),
        ("Presentations", ["ppt", "pptx", "key", "odp"]),
        ("Archives", ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"]),
        ("Installers", ["dmg", "pkg", "iso", "exe", "msi"]),
        ("Code", ["swift", "py", "js", "ts", "tsx", "jsx", "html", "css", "json", "sh", "c", "cpp", "h", "m", "java", "go",
                  "rs", "rb", "php", "sql", "yml", "yaml", "xml", "ipynb"]),
        ("Design", ["psd", "ai", "sketch", "fig", "xd", "indd", "afdesign", "afphoto"]),
        ("Books", ["epub", "mobi", "azw3"]),
        ("Fonts", ["ttf", "otf", "woff", "woff2"]),
    ]
    /// Half-downloaded files are never touched.
    static let partial: Set<String> = ["crdownload", "download", "part", "tmp", "opdownload", "partial"]
    static let projectMarkers = [".git", "Package.swift", "package.json", "Cargo.toml", "pyproject.toml", "Gemfile",
                                 "go.mod", "CMakeLists.txt", "Makefile", "pom.xml"]

    static func isScreenshot(_ name: String) -> Bool {
        ["Screenshot ", "Screen Shot ", "Screen Recording ", "CleanShot"].contains { name.hasPrefix($0) }
    }

    /// Why we shouldn't touch this folder, or nil if it's fine.
    static func refusal(for folder: URL) -> String? {
        let p = folder.standardizedFileURL.path
        let home = NSHomeDirectory()
        let blocked: Set<String> = ["/", "/Users", "/Applications", "/System", "/Library", "/usr", "/bin", "/sbin",
                                    "/private", "/Volumes", "/opt", home, home + "/Library"]
        if blocked.contains(p) { return "That one's too important for me to reorganise." }
        if p.hasSuffix(".app") || p.hasSuffix(".photoslibrary") || p.contains(".app/") {
            return "I don't tidy inside apps or photo libraries."
        }
        let fm = FileManager.default
        for m in projectMarkers where fm.fileExists(atPath: folder.appendingPathComponent(m).path) {
            return "That looks like a code project, so I'll leave it alone."
        }
        if let names = try? fm.contentsOfDirectory(atPath: folder.path),
           names.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
            return "That looks like a code project, so I'll leave it alone."
        }
        return nil
    }

    /// Top-level regular files only. Folders, packages, symlinks, hidden files, partial downloads
    /// and anything modified in the last two minutes are left alone.
    static func plan(_ folder: URL, now: Date = Date()) -> [OrgMove] {
        let keys: [URLResourceKey] = [.isPackageKey, .isSymbolicLinkKey, .contentModificationDateKey, .isRegularFileKey]
        guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                       options: [.skipsHiddenFiles]) else { return [] }
        var groups: [String: [(URL, Date)]] = [:]
        for u in items {
            guard let v = try? u.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
                  v.isSymbolicLink != true, v.isPackage != true else { continue }
            let ext = u.pathExtension.lowercased()
            if partial.contains(ext) { continue }
            let mod = v.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(mod) < 120 { continue }
            let cat: String
            if isScreenshot(u.lastPathComponent) {
                cat = "Screenshots"
            } else if let c = categories.first(where: { $0.1.contains(ext) }) {
                cat = c.0
            } else {
                cat = "Other"
            }
            groups[cat, default: []].append((u, mod))
        }
        var moves: [OrgMove] = []
        let cal = Calendar.current
        for (cat, files) in groups {
            for (u, mod) in files {
                var dest = cat
                if files.count > 40 {   // big piles get split by month
                    let c = cal.dateComponents([.year, .month], from: mod)
                    dest = String(format: "%@/%04d-%02d", cat, c.year ?? 0, c.month ?? 0)
                }
                moves.append(OrgMove(src: u, folder: dest))
            }
        }
        return moves.sorted { $0.folder == $1.folder ? $0.src.lastPathComponent < $1.src.lastPathComponent : $0.folder < $1.folder }
    }

    static func topFolder(_ m: OrgMove) -> String { m.folder.components(separatedBy: "/")[0] }

    @discardableResult
    static func perform(_ m: OrgMove, in folder: URL, log: inout OrgLog) -> URL? {
        let fm = FileManager.default
        let destDir = folder.appendingPathComponent(m.folder, isDirectory: true)
        var missing: [String] = []
        var probe = destDir
        while probe.path != folder.path && !fm.fileExists(atPath: probe.path) {
            missing.append(probe.path)
            probe = probe.deletingLastPathComponent()
        }
        if !missing.isEmpty {
            do { try fm.createDirectory(at: destDir, withIntermediateDirectories: true) } catch { return nil }
            log.created.append(contentsOf: missing)
        }
        let dest = Files.unique(destDir, m.src.deletingPathExtension().lastPathComponent, m.src.pathExtension)
        do { try fm.moveItem(at: m.src, to: dest) } catch { return nil }
        log.entries.append(OrgEntry(from: m.src.path, to: dest.path))
        return dest
    }

    /// Moves everything back and removes the folders we made, if they're empty. Returns how many files went back.
    @discardableResult
    static func undo(_ log: OrgLog) -> Int {
        let fm = FileManager.default
        var restored = 0
        for e in log.entries.reversed() where fm.fileExists(atPath: e.to) && !fm.fileExists(atPath: e.from) {
            if (try? fm.moveItem(atPath: e.to, toPath: e.from)) != nil { restored += 1 }
        }
        for dir in log.created.sorted(by: { $0.count > $1.count }) {
            let names = (try? fm.contentsOfDirectory(atPath: dir)) ?? []
            if names.allSatisfy({ $0 == ".DS_Store" }) { try? fm.removeItem(atPath: dir) }
        }
        return restored
    }
}

// MARK: - Finder bridge: which folder is the Finder window under Clawd showing?

enum FinderBridge {
    enum Result {
        case ok([(rect: CGRect, path: String)])
        case denied
        case failed
    }

    /// Finder windows front to back, with bounds in top-left screen coordinates.
    static func windows() -> Result {
        let src = """
        tell application "Finder"
            set out to ""
            repeat with w in (every Finder window)
                try
                    set b to bounds of w
                    set p to POSIX path of (target of w as alias)
                    set out to out & (item 1 of b as text) & "," & (item 2 of b as text) & "," & (item 3 of b as text) & "," & (item 4 of b as text) & "|" & p & linefeed
                end try
            end repeat
            return out
        end tell
        """
        guard let script = NSAppleScript(source: src) else { return .failed }
        var err: NSDictionary?
        let r = script.executeAndReturnError(&err)
        if let err {
            let n = err[NSAppleScript.errorNumber] as? Int ?? 0
            return n == -1743 ? .denied : .failed
        }
        var out: [(CGRect, String)] = []
        for line in (r.stringValue ?? "").split(separator: "\n") {
            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let n = parts[0].split(separator: ",").compactMap { Double($0) }
            guard n.count == 4 else { continue }
            out.append((CGRect(x: n[0], y: n[1], width: n[2] - n[0], height: n[3] - n[1]), parts[1]))
        }
        return .ok(out.map { (rect: $0.0, path: $0.1) })
    }
}

// MARK: - Animation pieces: folder bins and flying file icons

final class BinView: NSView {
    var name = ""
    var count = 0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
        bubbleCream.setFill()
        path.fill()
        clawdOrange.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        // little pixel folder
        NSGraphicsContext.current?.shouldAntialias = false
        let u: CGFloat = 3
        let ox = bounds.midX - 7 * u / 2 - u * 0.5, oy: CGFloat = 30
        func px(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: NSColor) {
            c.setFill()
            NSRect(x: ox + CGFloat(x) * u, y: oy + CGFloat(y) * u, width: CGFloat(w) * u, height: CGFloat(h) * u).fill()
        }
        let tab = rgb(0.93, 0.68, 0.25), body = rgb(0.99, 0.80, 0.35)
        px(0, 4, 3, 1, tab)
        px(0, 0, 8, 4, body)
        px(0, 3, 8, 1, tab)
        NSGraphicsContext.current?.shouldAntialias = true
        let la: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold),
                                                 .foregroundColor: clawdInk]
        let s = name as NSString
        let sz = s.size(withAttributes: la)
        s.draw(at: NSPoint(x: bounds.midX - sz.width / 2, y: 7), withAttributes: la)
        if count > 0 {
            let badge = NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 22, y: bounds.maxY - 22, width: 20, height: 20))
            clawdOrange.setFill()
            badge.fill()
            let ca: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
                                                     .foregroundColor: NSColor.white]
            let c = "\(count)" as NSString
            let csz = c.size(withAttributes: ca)
            c.draw(at: NSPoint(x: bounds.maxX - 12 - csz.width / 2, y: bounds.maxY - 12 - csz.height / 2), withAttributes: ca)
        }
    }
}

final class BinPanel: NSPanel {
    let binView = BinView(frame: NSRect(x: 0, y: 0, width: 80, height: 62))
    var base = CGPoint.zero
    var bounce: CGFloat = 0

    init(name: String) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 80, height: 62), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        binView.name = name
        contentView = binView
    }
    override var canBecomeKey: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class FlyPanel: NSPanel {
    let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 34, height: 34))
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 34, height: 34), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        contentView = imageView
    }
    override var canBecomeKey: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

struct OrgFly {
    var panel: FlyPanel
    var move: OrgMove
    var bin: String
    var from: CGPoint
    var to: CGPoint
    var t: Double
    var dur: Double
}
