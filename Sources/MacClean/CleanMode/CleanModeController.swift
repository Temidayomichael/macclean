import AppKit
import SwiftUI

/// Runs Clean Mode: locks the keyboard and trackpad, covers every screen with
/// an overlay that shows the countdown, and unlocks when the time is up or the
/// Escape key is held down.
@MainActor
final class CleanModeController: ObservableObject {
    static let durationKey = "cleanModeDuration"
    static let menuBarKey = "showInMenuBar"
    static let defaultDuration = 120
    static let durations: [(seconds: Int, label: String)] = [
        (30, "30 seconds"),
        (60, "1 minute"),
        (120, "2 minutes"),
        (300, "5 minutes"),
        (600, "10 minutes"),
    ]
    /// How long Escape has to be held to unlock before the timer ends.
    static let escapeHoldSeconds: TimeInterval = 3

    @Published private(set) var isActive = false
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    /// 0 to 1 while Escape is held down.
    @Published private(set) var escapeProgress: Double = 0
    @Published private(set) var hasAccessibility = InputBlocker.isTrusted(prompt: false)
    /// True while Clean Mode runs without Accessibility access: typing and
    /// clicking are blocked, but system shortcuts and media keys are not.
    @Published private(set) var isPartial = false
    /// Set by the menu bar when Clean Mode needs Accessibility access first;
    /// the main window switches to the Keyboard tab and clears it.
    @Published var setupRequested = false

    private var endDate = Date()
    private var escapeDownSince: Date?
    private var blocker: InputBlocker?
    private var overlays: [CleanModeOverlayWindow] = []
    private var monitors: [Any] = []
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?

    init() {
        // macOS sends no notification when Accessibility access changes, so
        // look again whenever the user comes back to the app.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshAccessibility() }
        }
    }

    static func label(forSeconds seconds: Int) -> String {
        durations.first { $0.seconds == seconds }?.label ?? "\(seconds) seconds"
    }

    /// Re-reads whether macOS trusts the app; there is no notification for it.
    func refreshAccessibility() {
        hasAccessibility = InputBlocker.isTrusted(prompt: false)
    }

    /// Shows the system dialog that offers to open the Accessibility settings.
    func requestAccessibility() {
        hasAccessibility = InputBlocker.isTrusted(prompt: true)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func start(seconds: Int) {
        guard !isActive else { return }
        refreshAccessibility()

        blocker = InputBlocker { [weak self] isDown in
            self?.escape(isDown: isDown)
        }
        isPartial = blocker == nil

        duration = TimeInterval(seconds)
        endDate = Date().addingTimeInterval(duration)
        remaining = duration
        escapeDownSince = nil
        escapeProgress = 0
        isActive = true

        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled, .userInitiated],
            reason: "Clean Mode keeps the countdown on screen"
        )

        NSApp.activate(ignoringOtherApps: true)
        showOverlays()
        installMonitors()
        NSCursor.hide()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.showOverlays() }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        guard isActive else { return }
        timer?.invalidate()
        timer = nil
        blocker?.stop()
        blocker = nil
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        // orderOut rather than close: closing the last window would quit the app
        // when the menu bar icon is hidden.
        for window in overlays {
            window.orderOut(nil)
        }
        overlays = []
        NSCursor.unhide()
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
        isActive = false
        isPartial = false
        escapeDownSince = nil
        escapeProgress = 0
        remaining = 0
        NSSound(named: "Glass")?.play()
    }

    // MARK: - Private

    private func escape(isDown: Bool) {
        guard isActive else { return }
        if isDown {
            if escapeDownSince == nil {
                escapeDownSince = Date()
            }
        } else {
            escapeDownSince = nil
            escapeProgress = 0
        }
    }

    private func tick() {
        guard isActive else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if let since = escapeDownSince {
            escapeProgress = min(1, Date().timeIntervalSince(since) / Self.escapeHoldSeconds)
            if escapeProgress >= 1 {
                stop()
                return
            }
        }
        if remaining <= 0 {
            stop()
        }
    }

    /// One overlay per screen, rebuilt when displays are plugged in or out.
    private func showOverlays() {
        for window in overlays {
            window.orderOut(nil)
        }
        overlays = NSScreen.screens.map { CleanModeOverlayWindow(screen: $0, controller: self) }
        for (index, window) in overlays.enumerated() {
            if index == 0 {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
        }
    }

    /// Fallback for when the event tap is unavailable: events that reach this
    /// app are dropped here, before any menu shortcut (such as Cmd-Q) sees them.
    private func installMonitors() {
        let keys: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: keys, handler: { [weak self] event in
            if event.type != .flagsChanged, event.keyCode == 53, !(event.type == .keyDown && event.isARepeat) {
                let isDown = event.type == .keyDown
                Task { @MainActor in self?.escape(isDown: isDown) }
            }
            return nil
        }) {
            monitors.append(monitor)
        }
        let pointer: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .mouseMoved, .scrollWheel, .magnify, .rotate, .swipe, .smartMagnify,
        ]
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: pointer, handler: { _ in nil }) {
            monitors.append(monitor)
        }
    }
}
