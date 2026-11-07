import AppKit
import SwiftUI

/// The Keyboard tab: start Clean Mode and manage what it needs.
struct KeyboardView: View {
    @EnvironmentObject private var cleanMode: CleanModeController
    @AppStorage(CleanModeController.durationKey) private var duration = CleanModeController.defaultDuration
    @AppStorage(CleanModeController.menuBarKey) private var showInMenuBar = true
    @State private var isConfirmingPartial = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Clean Mode")
                                .font(.title2.weight(.semibold))
                            Text("Locks the keyboard and trackpad so you can wipe your Mac without typing, clicking or triggering shortcuts. Every screen shows a countdown while it is on.")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack {
                        Picker("Lock for", selection: $duration) {
                            ForEach(CleanModeController.durations, id: \.seconds) { option in
                                Text(option.label).tag(option.seconds)
                            }
                        }
                        .frame(maxWidth: 240)
                        Spacer()
                        Button {
                            startOrAsk()
                        } label: {
                            Label("Start Clean Mode", systemImage: "lock.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(cleanMode.isActive)
                    }
                    Text("It unlocks on its own when the time is up. To unlock sooner, hold the Escape key for \(Int(CleanModeController.escapeHoldSeconds)) seconds.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Permissions") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: cleanMode.hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(cleanMode.hasAccessibility ? Color.green : Color.orange)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cleanMode.hasAccessibility ? "Accessibility access granted" : "Accessibility access needed")
                            .font(.headline)
                        Text(cleanMode.hasAccessibility
                             ? "MacClean can block every key, including system shortcuts like ⌘ Tab and ⌘ Space, the volume and brightness keys and the Globe key."
                             : "Without it, Clean Mode only blocks typing and clicks. System shortcuts, the volume and brightness keys and the Globe key still work. Allow MacClean under Privacy & Security > Accessibility.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if !cleanMode.hasAccessibility {
                        VStack(alignment: .trailing, spacing: 6) {
                            Button("Grant Access…") {
                                cleanMode.requestAccessibility()
                            }
                            Button("Open System Settings") {
                                cleanMode.openAccessibilitySettings()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Menu bar") {
                Toggle(isOn: $showInMenuBar) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Show MacClean in the menu bar")
                        Text("Start Clean Mode from the keyboard icon in the menu bar. While the icon is shown, MacClean keeps running after you close this window.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section("Tips") {
                VStack(alignment: .leading, spacing: 6) {
                    tip("Switch the Mac off or use Clean Mode; never spray liquid on it. Use a soft, lint-free cloth, barely damp with water.")
                    tip("The power button (Touch ID) is handled by macOS before MacClean sees it, so avoid pressing it.")
                    tip("Clean Mode blocks input from every keyboard, trackpad and mouse, including Bluetooth ones.")
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            cleanMode.refreshAccessibility()
        }
        .confirmationDialog(
            "Clean Mode can't block everything yet",
            isPresented: $isConfirmingPartial,
            titleVisibility: .visible
        ) {
            Button("Grant Access…") {
                cleanMode.requestAccessibility()
            }
            Button("Start Anyway") {
                cleanMode.start(seconds: duration)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("MacClean has no Accessibility access, so system shortcuts and the volume and brightness keys would still work while you wipe the keyboard. Typing and clicking are blocked either way.")
        }
    }

    private func startOrAsk() {
        cleanMode.refreshAccessibility()
        if cleanMode.hasAccessibility {
            cleanMode.start(seconds: duration)
        } else {
            isConfirmingPartial = true
        }
    }

    private func tip(_ text: String) -> some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}
