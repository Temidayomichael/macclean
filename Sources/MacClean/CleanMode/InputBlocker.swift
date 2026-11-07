import AppKit
import ApplicationServices
import CoreGraphics

/// Swallows every keyboard, trackpad, mouse and media-key event for the whole
/// login session using a CGEvent tap, so nothing you press while wiping the
/// Mac reaches macOS or any app. Needs Accessibility access; `init` returns
/// nil without it, and the caller falls back to locking only its own windows.
final class InputBlocker {
    /// Called on the main actor when the Escape key goes down (true) or up (false).
    private let onEscape: @MainActor (_ isDown: Bool) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    private static let escapeKeyCode: Int64 = 53
    /// NX_SYSDEFINED: volume, brightness, play/pause, keyboard backlight and Eject keys.
    private static let systemDefinedEventType: UInt32 = 14

    /// True when macOS lets this process install filtering event taps.
    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    init?(onEscape: @escaping @MainActor (_ isDown: Bool) -> Void) {
        self.onEscape = onEscape

        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .mouseMoved, .scrollWheel, .tabletPointer, .tabletProximity,
        ]
        var mask: CGEventMask = 0
        for type in types {
            mask |= CGEventMask(1) << CGEventMask(type.rawValue)
        }
        mask |= CGEventMask(1) << CGEventMask(Self.systemDefinedEventType)

        // A C callback cannot capture Swift context, so `self` travels in userInfo.
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let blocker = Unmanaged<InputBlocker>.fromOpaque(userInfo).takeUnretainedValue()
            return blocker.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return nil
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
    }

    deinit {
        stop()
    }

    /// Removes the tap. Input flows normally again as soon as this returns.
    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a tap off if it thinks the tap is too slow.
            // Switch it straight back on so the lock holds.
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .keyDown, .keyUp:
            if event.getIntegerValueField(.keyboardEventKeycode) == Self.escapeKeyCode {
                let isDown = type == .keyDown
                let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                if !(isDown && isRepeat) {
                    let onEscape = self.onEscape
                    Task { @MainActor in onEscape(isDown) }
                }
            }
            return nil
        default:
            // Returning nil drops the event: it never reaches the window server.
            return nil
        }
    }
}
