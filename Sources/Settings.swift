import Cocoa
import ServiceManagement

// MARK: - Settings window: every switch in one place, with its state visible

extension Pet {
    func setToggle(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        if key == "calendar" && value { enableCalendar() }
        if key == "clipboard" && !value { clipboard.removeAll() }
    }

    @objc func settingToggled(_ b: NSButton) {
        guard let key = b.identifier?.rawValue else { return }
        setToggle(key, b.state == .on)
    }

    @objc func settingLogin(_ b: NSButton) {
        toggleLogin()
        b.state = loginEnabled ? .on : .off
    }

    @objc func settingOutfit(_ p: NSPopUpButton) {
        UserDefaults.standard.set(p.selectedItem?.representedObject as? String ?? "auto", forKey: "outfit")
        iconCache.removeAll()
    }

    // building blocks
    private func label(_ s: String, size: CGFloat = 13, bold: Bool = false, gray: Bool = false) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.font = NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        t.textColor = gray ? .secondaryLabelColor : .labelColor
        t.lineBreakMode = .byWordWrapping
        t.maximumNumberOfLines = 0
        t.preferredMaxLayoutWidth = 440
        return t
    }

    private func checkbox(_ title: String, key: String, note: String? = nil) -> NSView {
        let b = NSButton(checkboxWithTitle: title, target: self, action: #selector(settingToggled(_:)))
        b.identifier = NSUserInterfaceItemIdentifier(key)
        b.state = on(key) ? .on : .off
        return withNote(b, note)
    }

    private func withNote(_ control: NSView, _ note: String?) -> NSView {
        guard let note else { return control }
        let n = label(note, size: 11, gray: true)
        let box = NSStackView(views: [control, n])
        box.orientation = .vertical
        box.alignment = .leading
        box.spacing = 2
        box.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        n.preferredMaxLayoutWidth = 420
        return box
    }

    private func page(_ rows: [NSView]) -> NSView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        let v = NSView()
        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: v.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -24),
        ])
        return v
    }

    private func tab(_ title: String, _ view: NSView) -> NSTabViewItem {
        let t = NSTabViewItem(identifier: title)
        t.label = title
        t.view = view
        return t
    }

    func settingsTabs() -> [NSTabViewItem] {
        // General
        let login = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(settingLogin(_:)))
        login.state = loginEnabled ? .on : .off
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let update = NSButton(title: "Check for updates now", target: self, action: #selector(manualUpdateCheck))
        let general = page([
            label("General", size: 15, bold: true),
            login,
            checkbox("Sounds", key: "sounds", note: "Soft 8-bit blips for everything he does."),
            checkbox("Quiet mode", key: "quiet", note: "Silences his chatter. It also switches on by itself during Zoom calls."),
            checkbox("Check for updates daily", key: "updates"),
            update,
            label("Clawd v\(version)", size: 11, gray: true),
            label(statsLine(), size: 11, gray: true),
        ])
        // Alerts
        let alerts = page([
            label("What he tells you about", size: 15, bold: true),
            checkbox("Claude Code finished", key: "claude", note: "Watches for a busy claude process and tells you when a run ends."),
            checkbox("Break nudges", key: "nudges", note: "Water, stretch and posture reminders every so often."),
            checkbox("Low battery warnings", key: "battery", note: "A heads-up at 20% when you're unplugged."),
            checkbox("Bedtime nudges", key: "bedtime"),
            checkbox("Git nudges", key: "gitnudges", note: "Uncommitted changes or unpushed commits."),
            checkbox("GitHub alerts", key: "ghwatch", note: "CI failures and review requests (needs the gh CLI)."),
            checkbox("Calendar heads-up", key: "calendar", note: "A few minutes before events. Asks for Calendar access."),
            checkbox("Pop out of the menu bar for alerts", key: "popout", note: "Off: alerts appear as a bubble under his icon and he stays put."),
        ])
        // Fun & look
        let outfit = NSPopUpButton(frame: .zero, pullsDown: false)
        for (title, key) in [("Auto (seasonal)", "auto"), ("None", "none"), ("Party hat", "party"), ("Santa hat", "santa"),
                             ("Wizard hat", "wizard"), ("Crown", "crown"), ("Pumpkin", "pumpkin")] {
            outfit.addItem(withTitle: title)
            outfit.lastItem?.representedObject = key
        }
        let current = UserDefaults.standard.string(forKey: "outfit") ?? "auto"
        if let i = outfit.itemArray.firstIndex(where: { ($0.representedObject as? String) == current }) { outfit.selectItem(at: i) }
        outfit.target = self
        outfit.action = #selector(settingOutfit(_:))
        let outfitRow = NSStackView(views: [label("Outfit"), outfit])
        outfitRow.spacing = 10
        let city = NSButton(title: "Set weather city…", target: self, action: #selector(setWeatherCity))
        let weatherRow = NSStackView(views: [label(weatherSummary()), city])
        weatherRow.spacing = 10
        let fun = page([
            label("Fun & look", size: 15, bold: true),
            checkbox("Weird moods", key: "moods", note: "Rare events: building a fort, peeking at you, sneezing, turning into a ghost."),
            checkbox("Climb on windows", key: "climb", note: "He hops onto the tops of your windows now and then."),
            checkbox("Keep clipboard history", key: "clipboard", note: "The last 10 things you copied, in memory only. Passwords are skipped."),
            outfitRow,
            weatherRow,
        ])
        // Shortcuts
        let shortcuts = page([
            label("Keyboard shortcuts", size: 15, bold: true),
            label("⌃⌥T   Screenshot to text\n⌃⌥C   Pick a colour\n⌃⌥Space   Ask Clawd (calculator, converter)\n⌃⌥P   Generate a password\n⌃⌥N   Quick note\n⌃⌥G   GitHub dashboard"),
            label("Tip: drag his menu bar icon to carry him out; drag him onto the menu bar to dock him.", size: 11, gray: true),
        ])
        return [tab("General", general), tab("Alerts", alerts), tab("Fun & look", fun), tab("Shortcuts", shortcuts)]
    }

    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = settingsWindow, w.isVisible { w.makeKeyAndOrderFront(nil); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 470), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Clawd Settings"
        w.isReleasedWhenClosed = false
        let tabs = NSTabView(frame: NSRect(x: 0, y: 0, width: 520, height: 470))
        tabs.autoresizingMask = [.width, .height]
        for t in settingsTabs() { tabs.addTabViewItem(t) }
        w.contentView = tabs
        w.center()
        settingsWindow = w
        w.makeKeyAndOrderFront(nil)
    }
}
