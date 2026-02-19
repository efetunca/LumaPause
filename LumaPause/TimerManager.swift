import AppKit
import SwiftUI

final class TimerManager: ObservableObject {

    // MARK: - Persisted settings
    struct Settings {
        var intervalSeconds: Int      // 20 dk
        var dimSeconds: Int           // 20 sn
        var countdownSeconds: Int     // 5 sn
        var extendSeconds: Int        // 60 sn
    }

    // UserDefaults keys
    private enum K {
        static let intervalSeconds = "intervalSeconds"
        static let dimSeconds = "dimSeconds"
        static let countdownSeconds = "countdownSeconds"
        static let launchAtLogin = "launchAtLogin"
    }

    // callbacks (UI AppDelegate’de)
    var onShowWarning: (() -> Void)?
    var onHideWarning: (() -> Void)?
    var onStateChanged: (() -> Void)?

    @Published private(set) var countdown: Int = 0

    private(set) var isRunning: Bool = false
    private(set) var isDimmingNow: Bool = false

    // Ne zaman “uyarı/countdown” başlayacak?
    private(set) var warningFireDate: Date?

    private var cycleTimer: Timer?
    private var countdownTimer: Timer?
    private var dimTimer: Timer?
    private var remainingToWarning: Int?
    private var remainingCountdown: Int?
    private var pausedByLock: Bool = false
    private var wasRunningBeforeLock: Bool = false

    private var overlayWindows: [NSWindow] = []

    // MARK: - Settings
    private(set) var settings: Settings = Settings(
        intervalSeconds: 20 * 60,
        dimSeconds: 20,
        countdownSeconds: 5,
        extendSeconds: 60
    )

    func prepare() {
        // Load saved settings if any
        let d = UserDefaults.standard
        let interval = d.integer(forKey: K.intervalSeconds)
        let dim = d.integer(forKey: K.dimSeconds)
        let cd = d.integer(forKey: K.countdownSeconds)

        if interval > 0 { settings.intervalSeconds = interval }
        if dim > 0 { settings.dimSeconds = dim }
        if cd > 0 { settings.countdownSeconds = cd }
    }

    func updateSettings(intervalSeconds: Int? = nil, dimSeconds: Int? = nil) {
        if let intervalSeconds { settings.intervalSeconds = max(10, intervalSeconds) }
        if let dimSeconds { settings.dimSeconds = max(1, dimSeconds) }

        let d = UserDefaults.standard
        d.set(settings.intervalSeconds, forKey: K.intervalSeconds)
        d.set(settings.dimSeconds, forKey: K.dimSeconds)
        d.set(settings.countdownSeconds, forKey: K.countdownSeconds)

        if isRunning { startCycle() } else { onStateChanged?() }
    }

    // MARK: - Control
    func startCycle() {
        stopAll()
        isRunning = true
        isDimmingNow = false
        let warnAfter = max(0, settings.intervalSeconds - settings.countdownSeconds)
        scheduleWarning(after: warnAfter)
        onStateChanged?()
    }

    func stopAll() {
        isRunning = false
        isDimmingNow = false

        cycleTimer?.invalidate(); cycleTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil
        dimTimer?.invalidate(); dimTimer = nil

        countdown = 0
        warningFireDate = nil
        pausedByLock = false
        wasRunningBeforeLock = false

        onHideWarning?()
        hideOverlay()
        onStateChanged?()
    }

    // MARK: - Scheduling
    private func scheduleWarning(after seconds: Int) {
        remainingToWarning = seconds
        warningFireDate = Date().addingTimeInterval(TimeInterval(seconds))
        onStateChanged?()

        cycleTimer?.invalidate()
        cycleTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            self?.remainingToWarning = nil
            self?.beginCountdown()
        }
        RunLoop.main.add(cycleTimer!, forMode: .common)
    }

    private func beginCountdown() {
        remainingCountdown = settings.countdownSeconds
        countdown = settings.countdownSeconds
        onShowWarning?()
        onStateChanged?()

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self else { return }
            
            self.countdown -= 1
            self.remainingCountdown = self.countdown
            self.onStateChanged?()

            if self.countdown <= 0 {
                t.invalidate()
                self.onHideWarning?()
                self.startDimming()
                self.remainingCountdown = nil
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func startDimming() {
        isDimmingNow = true
        warningFireDate = nil
        onStateChanged?()

        showOverlay()

        dimTimer?.invalidate()
        dimTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.dimSeconds), repeats: false) { [weak self] _ in
            guard let self else { return }
            self.hideOverlay()
            self.isDimmingNow = false
            self.onStateChanged?()
            self.startCycle()
        }
        RunLoop.main.add(dimTimer!, forMode: .common)
    }

    // MARK: - Buttons actions
    func skipCycle() {
        // uyarıyı / karartmayı iptal et ve 20 dk yeniden başlat
        countdownTimer?.invalidate(); countdownTimer = nil
        dimTimer?.invalidate(); dimTimer = nil
        onHideWarning?()
        hideOverlay()
        isDimmingNow = false
        startCycle()
    }

    func extendOneMinute() {
        // bu karartmayı iptal et, 1 dk sonra tekrar 5 sn countdown
        countdownTimer?.invalidate(); countdownTimer = nil
        onHideWarning?()
        hideOverlay()
        isDimmingNow = false
        scheduleWarning(after: settings.extendSeconds)
    }

    // MARK: - Overlay
    private func showOverlay() {
        hideOverlay()

        for screen in NSScreen.screens {
            let w = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            w.level = .screenSaver
            w.isOpaque = false
            w.backgroundColor = .clear
            w.ignoresMouseEvents = true
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let v = NSView(frame: screen.frame)
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor.black.withAlphaComponent(1).cgColor
            w.contentView = v

            w.makeKeyAndOrderFront(nil)
            overlayWindows.append(w)
        }
    }

    private func hideOverlay() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
    }

    // MARK: - Helpers for UI
    func secondsUntilWarning() -> Int? {
        guard let warningFireDate else { return nil }
        return max(0, Int(warningFireDate.timeIntervalSinceNow.rounded(.down)))
    }
    
    func pauseAndResetOnLock() {
        // lock olunca sadece çalışıyorsa aksiyon al
        guard isRunning else { return }

        wasRunningBeforeLock = true
        pausedByLock = true

        // timer'ları iptal et
        cycleTimer?.invalidate(); cycleTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil
        dimTimer?.invalidate(); dimTimer = nil

        // UI/overlay kapat
        onHideWarning?()
        hideOverlay()

        // state'i sıfırla
        countdown = 0
        warningFireDate = nil
        remainingToWarning = nil
        remainingCountdown = nil
        isDimmingNow = false

        // "dursun" => isRunning false yap
        isRunning = false

        onStateChanged?()
    }

    func resumeFromUnlockStartFresh() {
        // sadece lock yüzünden durduysa otomatik başlat
        guard pausedByLock else { return }
        pausedByLock = false
        
        // Lock öncesi çalışmıyorsa başlatma
        guard wasRunningBeforeLock else { return }
        wasRunningBeforeLock = false
        
        // 20 dk’dan yeniden başlat (countdown son 5 sn’de)
        startCycle()
    }
}
