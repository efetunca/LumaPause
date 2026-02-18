import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    private let timerManager = TimerManager()

    // Live menu items
    private var nextItem: NSMenuItem!
    private var startItem: NSMenuItem!
    private var stopItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    
    private var intervalMenu: NSMenu!
    private var dimMenu: NSMenu!

    private var intervalCustomValueItem: NSMenuItem!
    private var dimCustomValueItem: NSMenuItem!

    private let presetIntervals: [Int] = [5*60, 10*60, 20*60, 30*60]
    private let presetDims: [Int] = [10, 20, 30, 60]
    
    private var intervalItems: [NSMenuItem] = []
    private var dimItems: [NSMenuItem] = []

    private var uiTickTimer: Timer?

    // Warning popover (status bar’dan)
    private var warningPopover: StatusPopover?

    // LaunchAgent id
    private let launchAgentId = "com.efetunca.LumaPause"
    
    private var sessionActive = true

    func applicationDidFinishLaunching(_ notification: Notification) {

        timerManager.prepare()
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🌙"

        buildMenu()
        statusItem.menu = menu

        // Warning popover
        if let button = statusItem.button {
            warningPopover = StatusPopover(statusButton: button, rootView: WarningPopoverView(manager: timerManager))
        }

        // callbacks from TimerManager
        timerManager.onShowWarning = { [weak self] in
            guard let self else { return }
            guard self.sessionActive else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard self.sessionActive else { return }
                self.warningPopover?.setRootView(WarningPopoverView(manager: self.timerManager))
                self.warningPopover?.show()
            }
        }
        timerManager.onHideWarning = { [weak self] in
            self?.warningPopover?.close()
        }
        timerManager.onStateChanged = { [weak self] in
            self?.refreshMenuTitles()
        }

        // UI tick for live "Next dim in"
        uiTickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshMenuTitles()
        }
        RunLoop.main.add(uiTickTimer!, forMode: .common)

        refreshMenuTitles()
    }

    // MARK: - Menu
    private func buildMenu() {
        menu = NSMenu()

        nextItem = NSMenuItem(title: "Next dim in —", action: nil, keyEquivalent: "")
        nextItem.isEnabled = false
        menu.addItem(nextItem)

        startItem = NSMenuItem(title: "Start", action: #selector(start), keyEquivalent: "s")
        startItem.target = self
        menu.addItem(startItem)
        
        stopItem = NSMenuItem(title: "Stop", action: #selector(stop), keyEquivalent: "x")
        stopItem.target = self
        menu.addItem(stopItem)

        menu.addItem(.separator())

        // Interval submenu
        intervalMenu = NSMenu()

        intervalMenu.addItem(makeIntervalItem("5 min", minutes: 5))
        intervalMenu.addItem(makeIntervalItem("10 min", minutes: 10))
        intervalMenu.addItem(makeIntervalItem("20 min (default)", minutes: 20))
        intervalMenu.addItem(makeIntervalItem("30 min", minutes: 30))

        intervalMenu.addItem(.separator())

        // Dinamik custom value satırı (tıklanabilir olsun: mevcut custom'u tekrar seçmek de mümkün)
        intervalCustomValueItem = NSMenuItem(title: "Custom", action: #selector(setInterval(_:)), keyEquivalent: "")
        intervalCustomValueItem.target = self
        intervalMenu.addItem(intervalCustomValueItem)

        // Custom giriş satırı
        let intervalSetCustomItem = NSMenuItem(title: "Set Custom…", action: #selector(customInterval), keyEquivalent: "")
        intervalSetCustomItem.target = self
        intervalMenu.addItem(intervalSetCustomItem)

        let intervalItem = NSMenuItem(title: "Interval", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        // Dim duration submenu
        dimMenu = NSMenu()

        dimMenu.addItem(makeDimItem("10 sec", seconds: 10))
        dimMenu.addItem(makeDimItem("20 sec (default)", seconds: 20))
        dimMenu.addItem(makeDimItem("30 sec", seconds: 30))
        dimMenu.addItem(makeDimItem("60 sec", seconds: 60))

        dimMenu.addItem(.separator())

        dimCustomValueItem = NSMenuItem(title: "Custom", action: #selector(setDim(_:)), keyEquivalent: "")
        dimCustomValueItem.target = self
        dimMenu.addItem(dimCustomValueItem)

        let dimSetCustomItem = NSMenuItem(title: "Set Custom…", action: #selector(customDim), keyEquivalent: "")
        dimSetCustomItem.target = self
        dimMenu.addItem(dimSetCustomItem)

        let dimItem = NSMenuItem(title: "Dim Duration", action: nil, keyEquivalent: "")
        dimItem.submenu = dimMenu
        menu.addItem(dimItem)

        // Launch at login
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeIntervalItem(_ title: String, minutes: Int) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(setInterval(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = minutes * 60
        intervalItems.append(item)
        return item
    }

    private func makeDimItem(_ title: String, seconds: Int) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(setDim(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = seconds
        dimItems.append(item)
        return item
    }

    private func refreshMenuTitles() {
        // Next dim line
        if timerManager.isDimmingNow {
            nextItem.title = "Dimming now…"
        } else {
            if timerManager.countdown > 0 {
                nextItem.title = "Next dim in \(timerManager.countdown)s"
            } else if let sToWarning = timerManager.secondsUntilWarning() {
                let sToDim = sToWarning + timerManager.settings.countdownSeconds
                nextItem.title = "Next dim in \(formatMMSS(sToDim))"
            } else {
                nextItem.title = "Next dim in —"
            }
        }

        // Start/Stop enable states
        startItem.isEnabled = !timerManager.isRunning
        stopItem.isEnabled = timerManager.isRunning

        // Launch at login state
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        
        // ✓ states for Interval + Custom item
        let currentInterval = timerManager.settings.intervalSeconds

        // preset tikleri
        for item in intervalItems {
            let val = item.representedObject as? Int
            item.state = (val == currentInterval) ? .on : .off
        }

        // custom value satırı: current preset değilse göster + tik
        let isPresetInterval = presetIntervals.contains(currentInterval)
        intervalCustomValueItem.isHidden = isPresetInterval

        if !isPresetInterval {
            let minutes = Int(round(Double(currentInterval) / 60.0))
            intervalCustomValueItem.title = "Custom (\(minutes) min)"
            intervalCustomValueItem.representedObject = currentInterval
            intervalCustomValueItem.state = .on
        } else {
            intervalCustomValueItem.state = .off
        }


        // ✓ states for Dim + Custom item
        let currentDim = timerManager.settings.dimSeconds

        for item in dimItems {
            let val = item.representedObject as? Int
            item.state = (val == currentDim) ? .on : .off
        }

        let isPresetDim = presetDims.contains(currentDim)
        dimCustomValueItem.isHidden = isPresetDim

        if !isPresetDim {
            dimCustomValueItem.title = "Custom (\(currentDim) sec)"
            dimCustomValueItem.representedObject = currentDim
            dimCustomValueItem.state = .on
        } else {
            dimCustomValueItem.state = .off
        }
    }

    private func formatMMSS(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Actions
    @objc private func start() { timerManager.startCycle() }
    @objc private func stop() { timerManager.stopAll() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int else { return }
        timerManager.updateSettings(intervalSeconds: seconds)
    }

    @objc private func setDim(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int else { return }
        timerManager.updateSettings(dimSeconds: seconds)
    }

    @objc private func customInterval() {
        let val = promptForNumber(title: "Custom Interval", message: "Dakika cinsinden gir (örn: 20)", placeholder: "20")
        if let minutes = val, minutes > 0 {
            timerManager.updateSettings(intervalSeconds: minutes * 60)
        }
    }

    @objc private func customDim() {
        let val = promptForNumber(title: "Custom Dim Duration", message: "Saniye cinsinden gir (örn: 20)", placeholder: "20")
        if let sec = val, sec > 0 {
            timerManager.updateSettings(dimSeconds: sec)
        }
    }
    
    @objc private func screenLocked() {
        sessionActive = false
        timerManager.pauseAndResetOnLock()
    }

    @objc private func screenUnlocked() {
        sessionActive = true
        timerManager.resumeFromUnlockStartFresh()
    }

    private func promptForNumber(title: String, message: String, placeholder: String) -> Int? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message

        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        tf.placeholderString = placeholder
        alert.accessoryView = tf

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let res = alert.runModal()
        if res == .alertFirstButtonReturn {
            return Int(tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    // MARK: - Launch at Login (macOS 12 easiest: LaunchAgent)
    @objc private func toggleLaunchAtLogin() {
        let enabled = isLaunchAtLoginEnabled()
        if enabled {
            disableLaunchAtLogin()
        } else {
            enableLaunchAtLogin()
        }
        refreshMenuTitles()
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    private func enableLaunchAtLogin() {
        guard let plistURL = launchAgentPlistURL() else { return }
        guard let execURL = Bundle.main.executableURL else { return }

        let program = execURL.path

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentId)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(program)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """

        do {
            try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            bootstrapLaunchAgent(plistURL: plistURL)
            UserDefaults.standard.set(true, forKey: "launchAtLogin")
        } catch {
            print("LaunchAgent write error:", error)
        }
    }

    private func disableLaunchAtLogin() {
        guard let plistURL = launchAgentPlistURL() else { return }
        bootoutLaunchAgent()
        try? FileManager.default.removeItem(at: plistURL)
        UserDefaults.standard.set(false, forKey: "launchAtLogin")
    }

    private func launchAgentPlistURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(launchAgentId).plist")
    }

    private func bootstrapLaunchAgent(plistURL: URL) {
        // launchctl bootstrap gui/<uid> <plist>
        let uid = getuid()
        runProcess("/bin/launchctl", ["bootstrap", "gui/\(uid)", plistURL.path])
    }

    private func bootoutLaunchAgent() {
        // launchctl bootout gui/<uid>/label
        let uid = getuid()
        runProcess("/bin/launchctl", ["bootout", "gui/\(uid)/\(launchAgentId)"])
    }

    private func runProcess(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            print("Process error:", error)
        }
    }
}
