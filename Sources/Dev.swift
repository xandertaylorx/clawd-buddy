import Cocoa

// MARK: - Models

struct GitStatus {
    var name: String
    var branch: String
    var dirty: Int
    var ahead: Int
    var behind: Int
    var lastCommit: Date?
}

enum CI { case none, ok, fail, running }

struct GHRepo {
    var name: String, nwo: String, url: String
    var stars: Int
    var isPrivate: Bool
    var pushed: Date?
    var prs: Int
    var ci: CI
}
struct GHReview { var title: String, repo: String, url: String }
struct GHData { var login: String; var repos: [GHRepo]; var reviews: [GHReview]; var at: Date }

final class DevState {
    var watchedPorts: [Int] = (UserDefaults.standard.array(forKey: "watchedPorts") as? [Int]) ?? []
    var portUp: [Int: Bool] = [:]
    var listening: [(port: Int, name: String, pid: Int)] = []
    var lastPortPoll = 0.0
    var repos: [String] = UserDefaults.standard.stringArray(forKey: "gitRepos") ?? []
    var gitStatus: [String: GitStatus] = [:]
    var nudged: [String: Date] = [:]
    var lastGitPoll = 0.0
    var gh: GHData?
    var ghError: String?
    var ghFetching = false
    var lastGh = 0.0
    var lastCI: [String: CI] = [:]
    var seenReviews = Set<String>()
    var ghFirst = true
    let ghPanel = GitHubPanel()
    var ghHideAt = 0.0
    var attentionUntil = 0.0
    var attentionSayAt = 0.0
    var scannedRepos = UserDefaults.standard.bool(forKey: "scannedRepos")
}

// MARK: - Running tools

func runProcess(_ exe: String, _ args: [String], cwd: String? = nil, timeout: Double = 20) -> (out: String, status: Int32)? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: exe)
    p.arguments = args
    if let cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = Downloader.searchDirs.joined(separator: ":") + ":" + (env["PATH"] ?? "")
    env["GIT_TERMINAL_PROMPT"] = "0"
    p.environment = env
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if p.isRunning { p.terminate() } }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (String(decoding: data, as: UTF8.self), p.terminationStatus)
}

enum Dev {
    /// macOS and app helper services that nobody wants in a dev-server menu.
    static let noisy: Set<String> = ["rapportd", "ControlCenter", "sharingd", "homed", "NewsTodayIntents", "nsurlsessiond", "identityservicesd",
                                     "UA Cloud Helper", "WavesLocalServer", "WavesPluginServer", "Google Chrome Helper", "Spotify", "Dropbox",
                                     "loginwindow", "Safari", "Slack Helper", "Notes", "Mail", "AirPlayXPCHelper", "WiFiAgent", "remoted"]
    static func listeningPorts() -> [(port: Int, name: String, pid: Int)] {
        guard let r = runProcess("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-u", NSUserName(), "-F", "pcn"], timeout: 8) else { return [] }
        var out: [(Int, String, Int)] = []
        var pid = 0, name = ""
        for line in r.out.split(separator: "\n") {
            guard let f = line.first else { continue }
            let v = String(line.dropFirst())
            if f == "p" { pid = Int(v) ?? 0 }
            else if f == "c" { name = v }
            else if f == "n", let c = v.lastIndex(of: ":"), let port = Int(v[v.index(after: c)...]) {
                if !out.contains(where: { $0.0 == port }) { out.append((port, name, pid)) }
            }
        }
        return out.sorted { $0.0 < $1.0 }.map { (port: $0.0, name: $0.1, pid: $0.2) }
    }

    static func gitStatus(_ path: String) -> GitStatus? {
        guard let st = runProcess("/usr/bin/git", ["status", "--porcelain=v1", "-b"], cwd: path, timeout: 10), st.status == 0 else { return nil }
        let lines = st.out.split(separator: "\n").map(String.init)
        var branch = "?", ahead = 0, behind = 0
        if let h = lines.first, h.hasPrefix("## ") {
            let rest = String(h.dropFirst(3))
            branch = rest.components(separatedBy: "...")[0].components(separatedBy: " ")[0]
            func num(_ key: String) -> Int {
                guard let r = rest.range(of: key) else { return 0 }
                return Int(rest[r.upperBound...].prefix { $0.isNumber }) ?? 0
            }
            ahead = num("ahead ")
            behind = num("behind ")
        }
        var last: Date?
        if let l = runProcess("/usr/bin/git", ["log", "-1", "--format=%ct"], cwd: path, timeout: 10),
           let t = TimeInterval(l.out.trimmingCharacters(in: .whitespacesAndNewlines)) { last = Date(timeIntervalSince1970: t) }
        return GitStatus(name: (path as NSString).lastPathComponent, branch: branch, dirty: max(0, lines.count - 1),
                         ahead: ahead, behind: behind, lastCommit: last)
    }

    /// Looks one and two levels down in the usual project folders for git repos.
    static func scanRepos() -> [String] {
        let home = NSHomeDirectory()
        let roots = ["Developer", "Projects", "Code", "dev", "src", "Documents", "Desktop", "repos", "github"].map { home + "/" + $0 } + [home]
        let fm = FileManager.default
        var found: [String] = []
        func check(_ dir: String) { if fm.fileExists(atPath: dir + "/.git"), !found.contains(dir) { found.append(dir) } }
        for r in roots {
            check(r)
            for name in (try? fm.contentsOfDirectory(atPath: r)) ?? [] where !name.hasPrefix(".") && name != "Library" {
                let d = r + "/" + name
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: d, isDirectory: &isDir), isDir.boolValue else { continue }
                check(d)
                if r != home {
                    for sub in (try? fm.contentsOfDirectory(atPath: d)) ?? [] where !sub.hasPrefix(".") { check(d + "/" + sub) }
                }
            }
            if found.count >= 30 { break }
        }
        return found
    }

    // MARK: GitHub via the gh CLI

    static func fetchGitHub() -> (GHData?, String?) {
        guard let gh = Downloader.tool("gh") else { return (nil, "Install the GitHub CLI: brew install gh") }
        guard let u = runProcess(gh, ["api", "user", "-q", ".login"], timeout: 15), u.status == 0 else {
            return (nil, "Run `gh auth login` in Terminal first.")
        }
        let login = u.out.trimmingCharacters(in: .whitespacesAndNewlines)
        var repos: [GHRepo] = []
        if let r = runProcess(gh, ["repo", "list", "--limit", "7", "--json", "name,nameWithOwner,url,pushedAt,stargazerCount,isPrivate"], timeout: 25),
           r.status == 0, let arr = (try? JSONSerialization.jsonObject(with: Data(r.out.utf8))) as? [[String: Any]] {
            let iso = ISO8601DateFormatter()
            for d in arr {
                guard let name = d["name"] as? String, let nwo = d["nameWithOwner"] as? String else { continue }
                var repo = GHRepo(name: name, nwo: nwo, url: d["url"] as? String ?? "https://github.com/\(nwo)",
                                  stars: d["stargazerCount"] as? Int ?? 0, isPrivate: d["isPrivate"] as? Bool ?? false,
                                  pushed: (d["pushedAt"] as? String).flatMap { iso.date(from: $0) }, prs: 0, ci: .none)
                if let p = runProcess(gh, ["pr", "list", "-R", nwo, "--state", "open", "--json", "number", "--limit", "50"], timeout: 15),
                   let a = (try? JSONSerialization.jsonObject(with: Data(p.out.utf8))) as? [Any] { repo.prs = a.count }
                if let c = runProcess(gh, ["run", "list", "-R", nwo, "--limit", "1", "--json", "status,conclusion"], timeout: 15),
                   let a = (try? JSONSerialization.jsonObject(with: Data(c.out.utf8))) as? [[String: Any]], let run = a.first {
                    let status = run["status"] as? String ?? "", concl = run["conclusion"] as? String ?? ""
                    repo.ci = status != "completed" ? .running : (concl == "success" ? .ok : (concl.isEmpty || concl == "skipped" || concl == "cancelled" ? .none : .fail))
                }
                repos.append(repo)
            }
        }
        var reviews: [GHReview] = []
        if let s = runProcess(gh, ["search", "prs", "--review-requested=@me", "--state=open", "--json", "title,url,repository", "--limit", "5"], timeout: 20),
           let arr = (try? JSONSerialization.jsonObject(with: Data(s.out.utf8))) as? [[String: Any]] {
            for d in arr {
                reviews.append(GHReview(title: d["title"] as? String ?? "", repo: (d["repository"] as? [String: Any])?["nameWithOwner"] as? String ?? "",
                                        url: d["url"] as? String ?? ""))
            }
        }
        return (GHData(login: login, repos: repos, reviews: reviews, at: Date()), nil)
    }
}

// MARK: - Claude Code hook installer (merges into ~/.claude/settings.json, with a backup)

enum ClaudeHook {
    static let marker = "--needs-you"
    static var settingsURL: URL { URL(fileURLWithPath: NSHomeDirectory() + "/.claude/settings.json") }

    static func command() -> String { "\"\(Bundle.main.executablePath ?? "Clawd")\" \(marker)" }

    static func isInstalled(_ settings: [String: Any]) -> Bool {
        let groups = ((settings["hooks"] as? [String: Any])?["Notification"] as? [[String: Any]]) ?? []
        return groups.contains { g in ((g["hooks"] as? [[String: Any]]) ?? []).contains { ($0["command"] as? String)?.contains(marker) == true } }
    }

    static func merged(_ settings: [String: Any], command: String) -> [String: Any] {
        var s = settings
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        var groups = hooks["Notification"] as? [[String: Any]] ?? []
        groups.append(["matcher": "", "hooks": [["type": "command", "command": command]]])
        hooks["Notification"] = groups
        s["hooks"] = hooks
        return s
    }

    static func removed(_ settings: [String: Any]) -> [String: Any] {
        var s = settings
        guard var hooks = s["hooks"] as? [String: Any], var groups = hooks["Notification"] as? [[String: Any]] else { return s }
        groups = groups.compactMap { g in
            var g = g
            let kept = ((g["hooks"] as? [[String: Any]]) ?? []).filter { ($0["command"] as? String)?.contains(marker) != true }
            if kept.isEmpty { return nil }
            g["hooks"] = kept
            return g
        }
        if groups.isEmpty { hooks.removeValue(forKey: "Notification") } else { hooks["Notification"] = groups }
        if hooks.isEmpty { s.removeValue(forKey: "hooks") } else { s["hooks"] = hooks }
        return s
    }
}

// MARK: - GitHub dashboard panel

final class RepoListView: NSView {
    var data: GHData?
    var message: String? = "Loading…"
    var onOpen: ((String) -> Void)?
    var onRefresh: (() -> Void)?
    var onClose: (() -> Void)?
    private var hits: [(NSRect, String)] = []

    static let width: CGFloat = 400
    static func height(_ d: GHData?) -> CGFloat {
        guard let d else { return 90 }
        return 44 + 26 + CGFloat(d.repos.count) * 30 + (d.reviews.isEmpty ? 0 : 30 + CGFloat(d.reviews.count) * 28) + 12
    }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func text(_ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat = 11, weight: NSFont.Weight = .medium,
                      color: NSColor = clawdInk, maxW: CGFloat = 400, right: Bool = false) {
        var a: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: size, weight: weight), .foregroundColor: color]
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byTruncatingTail
        a[.paragraphStyle] = para
        let sz = (s as NSString).size(withAttributes: a)
        let w = min(sz.width, maxW)
        (s as NSString).draw(in: NSRect(x: right ? x - w : x, y: y, width: w + 2, height: sz.height), withAttributes: a)
    }

    private func ago(_ d: Date?) -> String {
        guard let d else { return "" }
        let s = Int(-d.timeIntervalSinceNow)
        if s < 3600 { return "\(max(1, s / 60))m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }

    override func draw(_ dirtyRect: NSRect) {
        hits = []
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14)
        bubbleCream.setFill()
        path.fill()
        clawdOrange.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        let H = bounds.height
        var y = H - 30   // text baseline offsets measured from the top
        text("GitHub", 16, y, size: 13, weight: .bold)
        if let d = data { text("@\(d.login)", 78, y + 1, size: 11, color: NSColor(white: 0.4, alpha: 1)) }
        text("↻", bounds.width - 52, y - 1, size: 14, color: clawdOrange)
        hits.append((NSRect(x: bounds.width - 62, y: y - 4, width: 24, height: 24), "refresh"))
        text("✕", bounds.width - 30, y, size: 12, color: NSColor(white: 0.45, alpha: 1))
        hits.append((NSRect(x: bounds.width - 40, y: y - 4, width: 28, height: 24), "close"))
        y -= 8
        guard let d = data else {
            text(message ?? "", 16, H / 2 - 20, size: 11, color: NSColor(white: 0.35, alpha: 1), maxW: bounds.width - 32)
            return
        }
        y -= 18
        text("RECENT REPOS", 16, y, size: 9, weight: .bold, color: NSColor(white: 0.5, alpha: 1))
        for r in d.repos {
            y -= 30
            let dot: NSColor = { switch r.ci { case .ok: return rgb(0.3, 0.7, 0.35); case .fail: return rgb(0.85, 0.25, 0.25)
                case .running: return rgb(0.95, 0.65, 0.2); case .none: return NSColor(white: 0.75, alpha: 1) } }()
            dot.setFill()
            NSBezierPath(ovalIn: NSRect(x: 16, y: y + 4, width: 9, height: 9)).fill()
            text(r.name + (r.isPrivate ? " 🔒" : ""), 32, y, size: 11, weight: .semibold, maxW: 170)
            if r.prs > 0 {
                let badge = "\(r.prs) PR\(r.prs == 1 ? "" : "s")"
                clawdOrange.setFill()
                NSBezierPath(roundedRect: NSRect(x: 214, y: y - 1, width: 44, height: 16), xRadius: 8, yRadius: 8).fill()
                text(badge, 220, y + 1, size: 9, weight: .bold, color: .white)
            }
            text("★ \(r.stars)", 300, y, size: 10, color: NSColor(white: 0.4, alpha: 1), right: false)
            text(ago(r.pushed), bounds.width - 18, y, size: 10, color: NSColor(white: 0.5, alpha: 1), right: true)
            hits.append((NSRect(x: 10, y: y - 6, width: bounds.width - 20, height: 28), r.url))
        }
        if !d.reviews.isEmpty {
            y -= 30
            text("WAITING FOR YOUR REVIEW", 16, y, size: 9, weight: .bold, color: NSColor(white: 0.5, alpha: 1))
            for rv in d.reviews {
                y -= 28
                text(rv.title, 16, y + 7, size: 11, weight: .medium, maxW: bounds.width - 32)
                text(rv.repo, 16, y - 5, size: 9, color: NSColor(white: 0.5, alpha: 1), maxW: bounds.width - 32)
                hits.append((NSRect(x: 10, y: y - 8, width: bounds.width - 20, height: 28), rv.url))
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let hit = hits.first(where: { $0.0.contains(p) }) else { return }
        switch hit.1 {
        case "close": onClose?()
        case "refresh": onRefresh?()
        default: onOpen?(hit.1)
        }
    }
}

final class GitHubPanel {
    let panel: NSPanel
    let list = RepoListView(frame: NSRect(x: 0, y: 0, width: RepoListView.width, height: 90))

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: RepoListView.width, height: 90), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = list
    }
    var isVisible: Bool { panel.isVisible }
    func hide() { panel.orderOut(nil) }
    func show() { panel.alphaValue = 1; panel.orderFrontRegardless() }

    func update(_ data: GHData?, message: String?) {
        list.data = data
        list.message = message
        let h = RepoListView.height(data)
        panel.setContentSize(NSSize(width: RepoListView.width, height: h))
        list.frame = NSRect(x: 0, y: 0, width: RepoListView.width, height: h)
        list.needsDisplay = true
    }

    func follow(anchor: NSRect, screenFrame sf: NSRect, topInset: CGFloat) {
        let w = panel.frame.width, h = panel.frame.height
        let x = min(max(anchor.midX - w / 2, sf.minX + 4), sf.maxX - w - 4)
        let y = min(anchor.maxY + 2, sf.maxY - topInset - h)
        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }
}

// MARK: - Pet: ports, git, github, hook, attention

extension Pet {
    // MARK: needs-you (Claude Code asks for you)

    func needsYou(_ text: String) {
        dev.attentionUntil = CACurrentMediaTime() + 120
        dev.attentionSayAt = CACurrentMediaTime() + 18
        updateOverride()
        alert(text.isEmpty ? "Claude needs you!" : text, hold: 20, sound: "x")
    }

    func clearAttention() {
        guard dev.attentionUntil > 0 else { return }
        dev.attentionUntil = 0
        updateOverride()
    }

    // MARK: ports

    func refreshPortsNow() {
        dev.listening = Dev.listeningPorts()
    }

    func pollPorts(_ mono: Double) {
        guard !dev.watchedPorts.isEmpty, mono - dev.lastPortPoll > 6 else { return }
        dev.lastPortPoll = mono
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let ports = Dev.listeningPorts()
            DispatchQueue.main.async {
                guard let self else { return }
                self.dev.listening = ports
                for w in self.dev.watchedPorts {
                    let up = ports.contains { $0.port == w }
                    if let was = self.dev.portUp[w], was != up {
                        self.alert(up ? "Port \(w) is back up." : "Port \(w) just went down.", hold: 6, sound: up ? nil : "x")
                    }
                    self.dev.portUp[w] = up
                }
            }
        }
    }

    @objc func watchPortPrompt() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Watch a port"
        alert.informativeText = "I'll tell you when something stops (or starts) listening on it, like your dev server."
        alert.addButton(withTitle: "Watch")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        field.placeholderString = "3000"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn, let p = Int(field.stringValue.trimmingCharacters(in: .whitespaces)),
              (1...65535).contains(p) else { return }
        toggleWatchPort(p)
    }

    func toggleWatchPort(_ p: Int) {
        if let i = dev.watchedPorts.firstIndex(of: p) {
            dev.watchedPorts.remove(at: i)
            dev.portUp[p] = nil
            say("Stopped watching port \(p).", hold: 2)
        } else {
            dev.watchedPorts.append(p)
            dev.portUp[p] = dev.listening.contains { $0.port == p }
            dev.lastPortPoll = 0
            say("Watching port \(p).", hold: 2)
        }
        UserDefaults.standard.set(dev.watchedPorts, forKey: "watchedPorts")
    }

    @objc func portOpen(_ item: NSMenuItem) {
        if let p = item.representedObject as? Int, let u = URL(string: "http://localhost:\(p)") { NSWorkspace.shared.open(u) }
    }
    @objc func portWatch(_ item: NSMenuItem) { if let p = item.representedObject as? Int { toggleWatchPort(p) } }
    @objc func portStop(_ item: NSMenuItem) {
        guard let info = item.representedObject as? [Int], info.count == 2 else { return }
        NSApp.activate(ignoringOtherApps: true)
        let name = dev.listening.first { $0.pid == info[1] }?.name ?? "process"
        let a = NSAlert()
        a.messageText = "Stop \(name) on port \(info[0])?"
        a.informativeText = "This sends it a normal quit signal (pid \(info[1]))."
        a.addButton(withTitle: "Stop it")
        a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        kill(pid_t(info[1]), SIGTERM)
        say("Stopped \(name).", hold: 2)
    }

    // MARK: git buddy

    func pollGit(_ mono: Double) {
        guard mono - dev.lastGitPoll > 90 else { return }
        dev.lastGitPoll = mono
        if dev.repos.isEmpty && !dev.scannedRepos {
            dev.scannedRepos = true
            UserDefaults.standard.set(true, forKey: "scannedRepos")
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let found = Dev.scanRepos()
                DispatchQueue.main.async {
                    guard let self, !found.isEmpty else { return }
                    self.dev.repos = found
                    UserDefaults.standard.set(found, forKey: "gitRepos")
                    self.dev.lastGitPoll = 0
                }
            }
            return
        }
        let repos = dev.repos
        guard !repos.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var out: [String: GitStatus] = [:]
            for r in repos { if let s = Dev.gitStatus(r) { out[r] = s } }
            DispatchQueue.main.async {
                guard let self else { return }
                self.dev.gitStatus = out
                guard self.on("gitnudges"), !self.isQuiet, self.focusEnd == nil, self.mode == .desk || self.mode == .docked else { return }
                for (path, s) in out {
                    let age = s.lastCommit.map { -$0.timeIntervalSinceNow } ?? 99999
                    if let last = self.dev.nudged[path], -last.timeIntervalSinceNow < 3 * 3600 { continue }
                    if s.dirty > 0 && age > 2 * 3600 {
                        self.dev.nudged[path] = Date()
                        self.alert("\(s.name): \(s.dirty) uncommitted change\(s.dirty == 1 ? "" : "s"). Commit?", hold: 6, sound: nil)
                        return
                    }
                    if s.dirty == 0 && s.ahead > 0 && age > 3600 {
                        self.dev.nudged[path] = Date()
                        self.alert("\(s.name): \(s.ahead) commit\(s.ahead == 1 ? "" : "s") not pushed.", hold: 6, sound: nil)
                        return
                    }
                }
            }
        }
    }

    @objc func addRepoPrompt() {
        NSApp.activate(ignoringOtherApps: true)
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.message = "Pick a git repository folder for Clawd to keep an eye on"
        guard p.runModal() == .OK, let u = p.url else { return }
        guard FileManager.default.fileExists(atPath: u.path + "/.git") else { say("That isn't a git repo.", hold: 3); return }
        if !dev.repos.contains(u.path) { dev.repos.append(u.path) }
        UserDefaults.standard.set(dev.repos, forKey: "gitRepos")
        dev.lastGitPoll = 0
        say("Watching \(u.lastPathComponent).", hold: 2)
    }

    @objc func findRepos() {
        say("Looking for repos…", hold: 2)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let found = Dev.scanRepos()
            DispatchQueue.main.async {
                guard let self else { return }
                for f in found where !self.dev.repos.contains(f) { self.dev.repos.append(f) }
                UserDefaults.standard.set(self.dev.repos, forKey: "gitRepos")
                self.dev.lastGitPoll = 0
                self.say("Watching \(self.dev.repos.count) repo\(self.dev.repos.count == 1 ? "" : "s").", hold: 3)
            }
        }
    }

    @objc func repoReveal(_ item: NSMenuItem) {
        if let p = item.representedObject as? String { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)]) }
    }
    @objc func repoTerminal(_ item: NSMenuItem) {
        if let p = item.representedObject as? String {
            NSWorkspace.shared.open([URL(fileURLWithPath: p)], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                    configuration: NSWorkspace.OpenConfiguration())
        }
    }
    @objc func repoRemove(_ item: NSMenuItem) {
        guard let p = item.representedObject as? String else { return }
        dev.repos.removeAll { $0 == p }
        dev.gitStatus[p] = nil
        UserDefaults.standard.set(dev.repos, forKey: "gitRepos")
    }

    // MARK: GitHub dashboard

    func setUpGitHubPanel() {
        dev.ghPanel.list.onOpen = { [weak self] url in
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
            self?.dev.ghHideAt = CACurrentMediaTime() + 8
        }
        dev.ghPanel.list.onRefresh = { [weak self] in self?.fetchGitHub(force: true) }
        dev.ghPanel.list.onClose = { [weak self] in self?.dev.ghPanel.hide() }
    }

    @objc func toggleGitHub() {
        if dev.ghPanel.isVisible { dev.ghPanel.hide(); return }
        guard mode == .desk || mode == .docked else { return }
        shelf.hide()
        hideTray()
        dev.ghPanel.update(dev.gh, message: dev.ghError ?? "Loading…")
        dev.ghHideAt = CACurrentMediaTime() + 25
        if mode == .docked { undockForPanel(); return }
        dev.ghPanel.show()
        if dev.gh == nil || CACurrentMediaTime() - dev.lastGh > 60 { fetchGitHub(force: true) }
    }

    /// The dashboard hangs off Clawd, so a docked Clawd steps out for it.
    func undockForPanel() {
        pendingPanel = true
        undock()
        dev.ghPanel.hide()
    }

    func fetchGitHub(force: Bool = false) {
        guard !dev.ghFetching else { return }
        dev.ghFetching = true
        dev.lastGh = CACurrentMediaTime()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let (data, err) = Dev.fetchGitHub()
            DispatchQueue.main.async {
                guard let self else { return }
                self.dev.ghFetching = false
                self.dev.ghError = err
                if let data {
                    // CI failures and new review requests are announced, once
                    if !self.dev.ghFirst && self.on("ghwatch") {
                        for r in data.repos where r.ci == .fail && self.dev.lastCI[r.nwo] != .fail {
                            self.alert("CI failed on \(r.name).", hold: 7)
                            break
                        }
                        for rv in data.reviews where !self.dev.seenReviews.contains(rv.url) {
                            self.alert("Review requested: \(rv.title)", hold: 8, sound: nil)
                            break
                        }
                    }
                    for r in data.repos { self.dev.lastCI[r.nwo] = r.ci }
                    for rv in data.reviews { self.dev.seenReviews.insert(rv.url) }
                    self.dev.ghFirst = false
                    self.dev.gh = data
                }
                if self.dev.ghPanel.isVisible { self.dev.ghPanel.update(self.dev.gh, message: err ?? "Loading…") }
            }
        }
    }

    // MARK: Claude Code alerts hook

    @objc func toggleClaudeHook() {
        NSApp.activate(ignoringOtherApps: true)
        let url = ClaudeHook.settingsURL
        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: url) {
            guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                say("I can't read ~/.claude/settings.json, so I left it alone.", hold: 5)
                return
            }
            settings = obj
        }
        let installed = ClaudeHook.isInstalled(settings)
        let a = NSAlert()
        a.messageText = installed ? "Remove Clawd's Claude Code alert?" : "Let Clawd alert you when Claude Code needs you?"
        a.informativeText = installed
            ? "This removes Clawd's entry from the Notification hook in ~/.claude/settings.json."
            : "This adds a Notification hook to ~/.claude/settings.json that runs `Clawd --needs-you`, so he waves and bounces whenever Claude Code is waiting for permission or input. A backup is saved next to the file first."
        a.addButton(withTitle: installed ? "Remove" : "Add hook")
        a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                let backup = url.deletingLastPathComponent().appendingPathComponent("settings.json.clawd-backup")
                try? FileManager.default.removeItem(at: backup)
                try FileManager.default.copyItem(at: url, to: backup)
            }
            let new = installed ? ClaudeHook.removed(settings) : ClaudeHook.merged(settings, command: ClaudeHook.command())
            let data = try JSONSerialization.data(withJSONObject: new, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            say(installed ? "Removed. I won't nag." : "Done! I'll wave when Claude needs you.", hold: 4)
        } catch {
            say("Couldn't write the settings file.", hold: 4)
        }
    }
}

extension Pet {
    /// Everything that wants a look about once a second.
    func extraChecks(_ mono: Double) {
        dayNightChecks()
        if wx.lat != nil && mono - wx.lastFetch > 1800 { fetchWeather() }
        pollPorts(mono)
        pollGit(mono)
        if on("ghwatch"), Downloader.tool("gh") != nil, mono - dev.lastGh > 600 { fetchGitHub() }
        if on("moods") { moodScheduler(mono) }
        if dev.attentionUntil > 0 {
            if mono > dev.attentionUntil {
                clearAttention()
            } else if mono > dev.attentionSayAt {
                dev.attentionSayAt = mono + 18
                Sfx.play(.alert)
                say("Claude needs you!", hold: 6)
            }
        }
    }
}
