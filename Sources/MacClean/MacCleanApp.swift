import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched with `swift run` (no .app bundle) so the
        // window comes to the front and the app gets a Dock icon.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in the menu bar when the icon is shown, so Clean Mode
        // can be started from there without the window.
        !UserDefaults.standard.bool(forKey: CleanModeController.menuBarKey)
    }
}

@main
struct MacCleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updateChecker = UpdateChecker()
    @StateObject private var cleanMode = CleanModeController()
    @AppStorage(UpdateChecker.automaticKey) private var automaticUpdateChecks = true
    @AppStorage(CleanModeController.menuBarKey) private var showInMenuBar = true
    @AppStorage(CleanModeController.durationKey) private var cleanModeDuration = CleanModeController.defaultDuration

    static let mainWindowID = "main"

    init() {
        UserDefaults.standard.register(defaults: [
            CleanModeController.menuBarKey: true,
            CleanModeController.durationKey: CleanModeController.defaultDuration,
        ])
    }

    var body: some Scene {
        WindowGroup("MacClean", id: Self.mainWindowID) {
            ContentView()
                .environmentObject(updateChecker)
                .environmentObject(cleanMode)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task { await updateChecker.check(manual: true) }
                }
                .disabled(updateChecker.isChecking)
                Toggle("Check for Updates Automatically", isOn: $automaticUpdateChecks)
                Divider()
                Button("MacClean on GitHub") {
                    NSWorkspace.shared.open(AppInfo.repositoryURL)
                }
            }
            CommandMenu("Clean Mode") {
                Button("Start Clean Mode") {
                    cleanMode.start(seconds: cleanModeDuration)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(cleanMode.isActive)
                Picker("Lock for", selection: $cleanModeDuration) {
                    ForEach(CleanModeController.durations, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                Divider()
                Toggle("Show in Menu Bar", isOn: $showInMenuBar)
            }
        }

        MenuBarExtra(isInserted: $showInMenuBar) {
            CleanModeMenu()
                .environmentObject(cleanMode)
        } label: {
            Image(systemName: cleanMode.isActive ? "lock.fill" : "keyboard")
        }
    }
}

/// Contents of the menu bar icon's menu.
struct CleanModeMenu: View {
    @EnvironmentObject private var cleanMode: CleanModeController
    @AppStorage(CleanModeController.durationKey) private var duration = CleanModeController.defaultDuration
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if cleanMode.isActive {
            Text("Clean Mode is on")
            Button("Stop Clean Mode") {
                cleanMode.stop()
            }
        } else {
            Button("Start Clean Mode (\(CleanModeController.label(forSeconds: duration)))") {
                start()
            }
        }
        Picker("Lock for", selection: $duration) {
            ForEach(CleanModeController.durations, id: \.seconds) { option in
                Text(option.label).tag(option.seconds)
            }
        }
        Divider()
        Button("Open MacClean") {
            showMainWindow()
        }
        Divider()
        Button("Quit MacClean") {
            NSApp.terminate(nil)
        }
    }

    private func start() {
        cleanMode.refreshAccessibility()
        if cleanMode.hasAccessibility {
            cleanMode.start(seconds: duration)
        } else {
            // Ask for Accessibility access from the window, where the system
            // dialog can be seen, instead of starting a half-locked session.
            cleanMode.setupRequested = true
            showMainWindow()
            cleanMode.requestAccessibility()
        }
    }

    private func showMainWindow() {
        openWindow(id: MacCleanApp.mainWindowID)
        NSApp.activate(ignoringOtherApps: true)
    }
}
