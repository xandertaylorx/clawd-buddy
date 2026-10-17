import Cocoa

// The organiser, downloader and Finder-drop prompt, as extensions of Pet.
extension Pet {
    // MARK: tray contents

    func isDirectory(_ u: URL) -> Bool { (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }

    func trayKinds(for items: DropItems) -> [Tile] {
        if !items.files.isEmpty { return items.files.contains(where: isDirectory) ? Tile.folders : Tile.files }
        if let l = items.link {
            switch Downloader.classify(l) {
            case .youtube: return [.mp3, .mp4]
            case .spotifyTrack: return [.mp3]
            case .other: return []
            }
        }
        return []
    }

    func trayEnter(_ items: DropItems) {
        guard mode == .desk else { return }
        let kinds = trayKinds(for: items)
        guard !kinds.isEmpty else { return }   // plain text / other links: dropping on Clawd saves a note
        promptFolder = nil
        tray.configure(kinds)
        trayUp = true
        trayHideAt = nil
        bubble.hide()
        shelf.hide()
        tray.show()
    }

    func keepTray(_ msg: String) {
        trayHideAt = CACurrentMediaTime() + 6
        say(msg, hold: 5)
    }

    func droppedOnClawd(_ items: DropItems) -> Bool {
        if !items.files.isEmpty {
            if items.files.contains(where: isDirectory) { keepTray("Drop that folder on a tile above me!"); return true }
            hideTray()
            runTile(.hold, items.files)
            return true
        }
        if let l = items.link, Downloader.classify(l) != .other {
            keepTray(Downloader.classify(l) == .youtube ? "Drop it on MP3 or MP4 above me!" : "Drop it on MP3 above me!")
            return true
        }
        hideTray()
        if let t = (items.text ?? items.link?.absoluteString)?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            notes.insert(t, at: 0)
            UserDefaults.standard.set(notes, forKey: "notes")
            say("Saved that as a note.", hold: 2)
            return true
        }
        return false
    }

    func tileDropped(_ kind: Tile, _ items: DropItems) {
        switch kind {
        case .mp3, .mp4:
            hideTray()
            if let l = items.link { startDownload(l, mp4: kind == .mp4) }
        case .organize:
            hideTray()
            if let d = items.files.first(where: isDirectory) { startOrganize(d, fromFinder: false) }
        case .cancel:
            hideTray()
        default:
            runTile(kind, items.files)
        }
    }

    /// Clicks on tiles in prompt mode (after dropping Clawd on a Finder window).
    func tileClicked(_ kind: Tile) {
        guard let folder = promptFolder else { return }
        hideTray()
        if kind == .organize { startOrganize(folder, fromFinder: true) }
    }

    // MARK: dropping Clawd onto a Finder window

    func finderWindowUnder(_ cocoa: CGPoint) -> Bool {
        let H = NSScreen.screens[0].frame.height
        let cg = CGPoint(x: cocoa.x, y: H - cocoa.y)
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerName as String] as? String) != "Clawd",
                  let bd = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: bd), r.contains(cg) else { continue }
            return (w[kCGWindowOwnerName as String] as? String) == "Finder"
        }
        return false
    }

    func checkFinderDrop(_ cocoa: CGPoint) {
        guard finderWindowUnder(cocoa) else { return }
        let H = NSScreen.screens[0].frame.height
        let cg = CGPoint(x: cocoa.x, y: H - cocoa.y)
        DispatchQueue.global(qos: .userInitiated).async {
            let r = FinderBridge.windows()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch r {
                case .denied:
                    self.say("I need permission to see Finder (System Settings → Privacy & Security → Automation).", hold: 8)
                case .failed:
                    break
                case .ok(let wins):
                    if let w = wins.first(where: { $0.rect.contains(cg) }) {
                        self.pendingFolder = URL(fileURLWithPath: w.path)
                        self.maybeShowPrompt()
                    }
                }
            }
        }
    }

    func maybeShowPrompt() {
        guard let folder = pendingFolder, mode == .desk else { return }
        pendingFolder = nil
        if let why = Organizer.refusal(for: folder) { say(why, hold: 4); return }
        let n = Organizer.plan(folder).count
        if n == 0 { say("\(folder.lastPathComponent) is already tidy! ✨", hold: 3); return }
        promptFolder = folder
        tray.configure([.organize, .cancel])
        trayUp = true
        trayHideAt = CACurrentMediaTime() + 25
        shelf.hide()
        tray.show()
        say("\(folder.lastPathComponent) has \(n) file\(n == 1 ? "" : "s") I can sort. Organise it?", hold: 24, typewriter: false)
    }

    var bubbleAnchor: NSRect {
        if mode == .organizing { return orgBubbleAnchor }
        if mode == .flap { return fl.anchor }
        if trayUp && tray.isVisible { return tray.panel.frame }
        return panel.frame
    }

    // MARK: organise with animation

    func startOrganize(_ folder: URL, fromFinder: Bool) {
        guard mode == .desk else { return }
        if let why = Organizer.refusal(for: folder) { say(why, hold: 4); return }
        let all = Organizer.plan(folder)
        if all.isEmpty { say("\(folder.lastPathComponent) is already tidy!", hold: 3); brain.start(.dance); return }
        hideTray()
        shelf.hide()
        bubble.hide()
        perch = nil
        redockAt = nil
        orgFolder = folder
        orgOpenAfter = !fromFinder
        orgLog = OrgLog()
        orgLog.folder = folder.path
        orgTotal = all.count
        // animate a sample (at most 36 files); the rest are moved quietly at the end
        let step = max(1, all.count / 36)
        orgQueue = []
        orgSilent = []
        for (i, m) in all.enumerated() {
            if i % step == 0 && orgQueue.count < 36 { orgQueue.append(m) } else { orgSilent.append(m) }
        }
        orgBinOrder = Array(Set(all.map { Organizer.topFolder($0) })).sorted()
        orgBins = [:]
        for n in orgBinOrder { orgBins[n] = BinPanel(name: n) }
        layoutBins()
        orgIdx = 0
        orgFly = []
        orgSpawnIn = 0.5
        orgT = 0
        orgHudIn = 0
        orgFinished = false
        y = floorY
        mode = .organizing
    }

    func layoutBins() {
        let vis = screen.visibleFrame
        let w: CGFloat = 80, gap: CGFloat = 10
        let perRow = max(1, min(7, Int((vis.width - 40) / (w + gap))))
        let rows = (orgBinOrder.count + perRow - 1) / perRow
        let baseY = floorY + 128
        for (i, name) in orgBinOrder.enumerated() {
            let row = i / perRow, col = i % perRow
            let inRow = min(perRow, orgBinOrder.count - row * perRow)
            let rowW = CGFloat(inRow) * w + CGFloat(inRow - 1) * gap
            let bx = vis.midX - rowW / 2 + CGFloat(col) * (w + gap)
            let by = baseY + CGFloat(rows - 1 - row) * 72
            guard let b = orgBins[name] else { continue }
            b.base = CGPoint(x: bx, y: by)
            b.setFrameOrigin(b.base)
            b.alphaValue = 1
            b.orderFrontRegardless()
        }
        orgBubbleAnchor = NSRect(x: vis.midX - 1, y: baseY + CGFloat(rows) * 72 - 6, width: 2, height: 0)
    }

    func spawnFly(_ m: OrgMove) {
        let name = Organizer.topFolder(m)
        guard let bin = orgBins[name] else { return }
        let panel = orgFlyPool.popLast() ?? FlyPanel()
        let icon = NSWorkspace.shared.icon(forFile: m.src.path)
        icon.size = NSSize(width: 34, height: 34)
        panel.imageView.image = icon
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        let from = CGPoint(x: x + Pet.size.width - 10, y: y + 44)
        let to = CGPoint(x: bin.base.x + 40, y: bin.base.y + 34)
        orgFly.append(OrgFly(panel: panel, move: m, bin: name, from: from, to: to, t: 0, dur: .random(in: 0.5...0.7)))
    }

    func orgTick(_ dt: Double, now: Double) {
        guard let folder = orgFolder else { mode = .desk; return }
        orgT += dt
        let s = Int(orgT / 0.1)
        var p = Pose()
        p.eyes = .happy
        if orgFinished {
            p.armL = 5; p.armR = 5; p.bob = s % 2
        } else {
            p.armL = s % 2 == 0 ? 5 : 1
            p.armR = s % 2 == 0 ? 1 : 5
            p.legs = s % 2 + 1
            p.bob = s % 2
        }
        view.pose = p
        y = floorY
        moveWindow()

        if !orgFinished {
            orgSpawnIn -= dt
            if orgSpawnIn <= 0, orgIdx < orgQueue.count {
                spawnFly(orgQueue[orgIdx])
                orgIdx += 1
                orgSpawnIn = max(0.07, min(0.22, 5.0 / Double(max(1, orgQueue.count))))
            }
        }

        var keep: [OrgFly] = []
        for var f in orgFly {
            f.t += dt
            let u = min(1, f.t / f.dur)
            let px = f.from.x + (f.to.x - f.from.x) * CGFloat(u)
            let py = f.from.y + (f.to.y - f.from.y) * CGFloat(u) + 80 * CGFloat(4 * u * (1 - u))
            f.panel.setFrameOrigin(CGPoint(x: px - 17, y: py - 17))
            if u >= 1 {
                if Organizer.perform(f.move, in: folder, log: &orgLog) != nil {
                    orgBins[f.bin]?.binView.count += 1
                    orgBins[f.bin]?.bounce = 10
                    Sfx.play(.drop, volume: 0.15)
                }
                f.panel.orderOut(nil)
                orgFlyPool.append(f.panel)
            } else {
                keep.append(f)
            }
        }
        orgFly = keep

        for (_, b) in orgBins {
            if b.bounce > 0.3 {
                b.bounce *= 0.84
                b.setFrameOrigin(CGPoint(x: b.base.x, y: b.base.y + b.bounce))
            } else if b.bounce != 0 {
                b.bounce = 0
                b.setFrameOrigin(b.base)
            }
        }

        if !orgFinished {
            orgHudIn -= dt
            if orgHudIn <= 0 {
                orgHudIn = 0.3
                bubble.show("Sorting \(folder.lastPathComponent)…  \(orgLog.entries.count)/\(orgTotal)", hold: 0.8, typewriter: false)
            }
            if orgIdx >= orgQueue.count && orgFly.isEmpty { finishOrganize(folder, now: now) }
        } else if now > orgEndAt {
            endOrganizeUI()
        }
    }

    func finishOrganize(_ folder: URL, now: Double) {
        for m in orgSilent {
            if Organizer.perform(m, in: folder, log: &orgLog) != nil { orgBins[Organizer.topFolder(m)]?.binView.count += 1 }
        }
        orgSilent = []
        if let data = try? JSONEncoder().encode(orgLog) { UserDefaults.standard.set(data, forKey: "lastOrganize") }
        orgFinished = true
        Sfx.play(.fanfare)
        orgEndAt = now + 4.5
        let n = orgLog.entries.count
        let k = orgBinOrder.count
        bubble.show("Sorted \(n) file\(n == 1 ? "" : "s") into \(k) folder\(k == 1 ? "" : "s") ✨  Undo is in my menu.",
                    hold: 5, typewriter: false)
        if orgOpenAfter { NSWorkspace.shared.open(folder) }
    }

    func endOrganizeUI() {
        for (_, b) in orgBins { b.orderOut(nil) }
        for f in orgFly { f.panel.orderOut(nil) }
        orgBins = [:]
        orgFly = []
        orgFolder = nil
        mode = .desk
        brain.start(.idle, dur: 1)
    }

    @objc func undoOrganize() {
        guard mode == .desk || mode == .docked,
              let data = UserDefaults.standard.data(forKey: "lastOrganize"),
              let log = try? JSONDecoder().decode(OrgLog.self, from: data) else {
            say("Nothing to undo.", hold: 2)
            return
        }
        let n = Organizer.undo(log)
        UserDefaults.standard.removeObject(forKey: "lastOrganize")
        brain.start(.wave)
        say("Put \(n) file\(n == 1 ? "" : "s") back in \((log.folder as NSString).lastPathComponent).", hold: 4)
    }

    // MARK: link downloads

    func startDownload(_ link: URL, mp4: Bool) {
        let kind = Downloader.classify(link)
        guard Downloader.tool("yt-dlp") != nil, Downloader.tool("ffmpeg") != nil else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("brew install yt-dlp ffmpeg", forType: .string)
            alert("I need yt-dlp and ffmpeg for that. I copied the install command: paste it in Terminal, then try again.",
                  hold: 9, sound: "Pop")
            return
        }
        if !UserDefaults.standard.bool(forKey: "dlNoticed") {
            UserDefaults.standard.set(true, forKey: "dlNoticed")
            say("Only grab things you're allowed to keep!", hold: 4)
        }
        downloads += 1
        updateOverride()
        lastDlSay = 0

        func finish(_ r: DLResult) {
            downloads = max(0, downloads - 1)
            updateOverride()
            switch r {
            case .success(let url):
                brain.start(.dance)
                Sfx.play(.fanfare)
                say("Saved “\(url.deletingPathExtension().lastPathComponent)”", hold: 6)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            case .failure(let why):
                say("Download failed: \(why)", hold: 7)
            }
        }
        func go(_ source: String, name: String?) {
            Downloader.run(source: source, mp4: mp4, fileName: name, progress: { [weak self] pct in
                guard let self else { return }
                let now = CACurrentMediaTime()
                if now - self.lastDlSay > 1 {
                    self.lastDlSay = now
                    self.say("⬇ \(mp4 ? "Video" : "Audio") \(pct)%", hold: 2, typewriter: false)
                }
            }, done: finish)
        }
        if kind == .spotifyTrack {
            say("Finding that track…", hold: 3)
            Downloader.spotifyQuery(link) { [weak self] q in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard let q else {
                        self.downloads = max(0, self.downloads - 1)
                        self.updateOverride()
                        self.say("I couldn't read that Spotify link.", hold: 4)
                        return
                    }
                    go("ytsearch1:\(q)", name: q)
                }
            }
        } else {
            say("Starting download…", hold: 3)
            go(link.absoluteString, name: nil)
        }
    }
}
