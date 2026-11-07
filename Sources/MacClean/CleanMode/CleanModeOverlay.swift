import AppKit
import SwiftUI

/// A borderless window above everything else (including the menu bar and
/// full-screen apps) that covers one screen while Clean Mode is on.
final class CleanModeOverlayWindow: NSWindow {
    init(screen: NSScreen, controller: CleanModeController) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        contentView = NSHostingView(rootView: CleanModeOverlayView().environmentObject(controller))
        setFrame(screen.frame, display: true)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Swallow anything that still arrives, instead of beeping or quitting.
    override func keyDown(with event: NSEvent) {}
    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) {}
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
    override func cancelOperation(_ sender: Any?) {}
}

struct CleanModeOverlayView: View {
    @EnvironmentObject private var cleanMode: CleanModeController

    private var remainingText: String {
        let total = Int(cleanMode.remaining.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var fraction: Double {
        guard cleanMode.duration > 0 else { return 0 }
        return cleanMode.remaining / cleanMode.duration
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.94)
            VStack(spacing: 28) {
                Image(systemName: "keyboard")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.9))

                VStack(spacing: 8) {
                    Text("Clean Mode")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                    Text("Keyboard and trackpad are locked. Wipe away.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: fraction)
                    Text(remainingText)
                        .font(.system(size: 44, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 180, height: 180)

                VStack(spacing: 10) {
                    Text("Unlocks when the timer ends. To unlock now, hold esc for \(Int(CleanModeController.escapeHoldSeconds)) seconds.")
                        .foregroundStyle(.secondary)
                    ProgressView(value: cleanMode.escapeProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 220)
                        .opacity(cleanMode.escapeProgress > 0 ? 1 : 0)
                }

                if cleanMode.isPartial {
                    Label(
                        "MacClean has no Accessibility access, so system shortcuts and the volume and brightness keys still work. Grant it in the Keyboard tab for a full lock.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.callout)
                    .foregroundStyle(Color.yellow)
                    .frame(maxWidth: 520)
                    .multilineTextAlignment(.leading)
                }
            }
            .multilineTextAlignment(.center)
            .padding(40)
        }
        .foregroundStyle(Color.white)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
}
