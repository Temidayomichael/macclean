import AppKit
import Foundation

/// An application bundle found in one of the Applications folders.
struct InstalledApp: Identifiable, Hashable {
    let url: URL
    /// Name as shown in Finder (file name without the .app extension).
    let name: String
    /// CFBundleName from Info.plist, when it differs from the file name.
    let bundleName: String?
    let bundleID: String?
    let version: String?
    /// nil while the size is still being computed.
    var size: Int64?

    var id: URL { url }

    /// Apple's own apps are protected by the system and can't be removed.
    var isSystemApp: Bool {
        bundleID?.lowercased().hasPrefix("com.apple.") ?? false
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.url == rhs.url && lhs.size == rhs.size
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

/// A file or folder in ~/Library that belongs to an app.
struct LeftoverItem: Identifiable, Hashable {
    let url: URL
    let category: String
    let size: Int64

    var id: URL { url }

    var displayPath: String {
        PathDisplay.abbreviate(url)
    }
}

/// A group of removable junk, such as caches or logs.
struct JunkCategory: Identifiable, Hashable {
    enum Mode {
        /// Remove everything inside the folder but keep the folder itself.
        case children
        /// Remove the folder itself.
        case whole
    }

    let id: String
    let name: String
    let detail: String
    let url: URL
    let mode: Mode
    /// Items that can only be deleted permanently (for example the Trash itself).
    let permanentOnly: Bool

    var displayPath: String {
        PathDisplay.abbreviate(url)
    }
}

struct JunkScanResult: Identifiable {
    let category: JunkCategory
    let items: [URL]
    let size: Int64

    var id: String { category.id }
}

enum PathDisplay {
    static func abbreviate(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
