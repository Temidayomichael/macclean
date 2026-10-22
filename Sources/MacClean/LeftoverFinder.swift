import Foundation

/// Finds the support files an app leaves behind in ~/Library.
enum LeftoverFinder {
    private struct Location {
        let label: String
        let relativePath: String
        /// Loose matching: the bundle ID may appear anywhere in the file name
        /// (group containers are named "TEAMID.com.vendor.app") and crash
        /// reports are named "AppName-2026-01-01-120000.ips".
        let fuzzy: Bool
    }

    private static let locations: [Location] = [
        Location(label: "Application Support", relativePath: "Library/Application Support", fuzzy: false),
        Location(label: "Caches", relativePath: "Library/Caches", fuzzy: false),
        Location(label: "Preferences", relativePath: "Library/Preferences", fuzzy: false),
        Location(label: "Preferences (ByHost)", relativePath: "Library/Preferences/ByHost", fuzzy: false),
        Location(label: "Logs", relativePath: "Library/Logs", fuzzy: false),
        Location(label: "Crash reports", relativePath: "Library/Logs/DiagnosticReports", fuzzy: true),
        Location(label: "Saved state", relativePath: "Library/Saved Application State", fuzzy: false),
        Location(label: "Containers", relativePath: "Library/Containers", fuzzy: false),
        Location(label: "Group containers", relativePath: "Library/Group Containers", fuzzy: true),
        Location(label: "Application scripts", relativePath: "Library/Application Scripts", fuzzy: true),
        Location(label: "WebKit", relativePath: "Library/WebKit", fuzzy: false),
        Location(label: "HTTP storage", relativePath: "Library/HTTPStorages", fuzzy: false),
        Location(label: "Cookies", relativePath: "Library/Cookies", fuzzy: false),
        Location(label: "Launch agents", relativePath: "Library/LaunchAgents", fuzzy: false),
    ]

    static func find(for app: InstalledApp) -> [LeftoverItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let bundleID = app.bundleID?.lowercased()

        // Very short names ("Go", "VM") match too much, so they are ignored.
        var names: Set<String> = [app.name.lowercased()]
        if let bundleName = app.bundleName?.lowercased() {
            names.insert(bundleName)
        }
        names = names.filter { $0.count >= 3 }

        var items: [LeftoverItem] = []
        for location in locations {
            let directory = home.appendingPathComponent(location.relativePath, isDirectory: true)
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            )) ?? []
            for url in contents where matches(url, bundleID: bundleID, names: names, fuzzy: location.fuzzy) {
                items.append(LeftoverItem(
                    url: url,
                    category: location.label,
                    size: DiskUsage.size(of: url)
                ))
            }
        }
        return items.sorted { $0.url.path < $1.url.path }
    }

    private static func matches(_ url: URL, bundleID: String?, names: Set<String>, fuzzy: Bool) -> Bool {
        let fileName = url.lastPathComponent.lowercased()
        // "com.vendor.app.plist" -> "com.vendor.app"
        let stem = url.deletingPathExtension().lastPathComponent.lowercased()

        if let bundleID, !bundleID.isEmpty {
            if fileName == bundleID || stem == bundleID {
                return true
            }
            // Helpers and per-host preferences: "com.vendor.app.helper", "com.vendor.app.<UUID>.plist"
            if fileName.hasPrefix(bundleID + ".") {
                return true
            }
            if fuzzy && fileName.contains(bundleID) {
                return true
            }
        }

        for name in names {
            if stem == name || fileName == name {
                return true
            }
            if fuzzy && (fileName.hasPrefix(name + "-") || fileName.hasPrefix(name + "_")) {
                return true
            }
        }
        return false
    }
}
