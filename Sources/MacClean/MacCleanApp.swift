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
        true
    }
}

@main
struct MacCleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updateChecker = UpdateChecker()
    @AppStorage(UpdateChecker.automaticKey) private var automaticUpdateChecks = true

    var body: some Scene {
        WindowGroup("MacClean") {
            ContentView()
                .environmentObject(updateChecker)
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
        }
    }
}
