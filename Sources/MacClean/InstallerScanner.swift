import Foundation

/// A disk image or installer package sitting in Downloads or on the Desktop.
struct InstallerFile: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let modified: Date
    /// Name of an installed app whose name appears in the file name, if any.
    let installedAppName: String?

    var id: URL { url }

    var fileName: String { url.lastPathComponent }

    var folder: String { PathDisplay.abbreviate(url.deletingLastPathComponent()) }
}

enum InstallerScanner {
    static let extensions: Set<String> = ["dmg", "pkg", "mpkg", "xip"]

    static var searchDirectories: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Downloads", isDirectory: true),
            home.appendingPathComponent("Desktop", isDirectory: true),
        ]
    }

    /// Installers in Downloads and Desktop, up to three folders deep.
    /// Files whose name matches an installed app are listed first.
    static func find() -> [InstallerFile] {
        let appNames = AppScanner.installedApps().map(\.name)
        var items: [InstallerFile] = []

        for directory in searchDirectories {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                if enumerator.level > 3 {
                    enumerator.skipDescendants()
                    continue
                }
                guard extensions.contains(url.pathExtension.lowercased()) else { continue }
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                items.append(InstallerFile(
                    url: url,
                    size: DiskUsage.size(of: url),
                    modified: modified,
                    installedAppName: matchingApp(for: url, among: appNames)
                ))
            }
        }

        return items.sorted { a, b in
            let aInstalled = a.installedAppName != nil
            let bInstalled = b.installedAppName != nil
            if aInstalled != bInstalled { return aInstalled }
            return a.modified > b.modified
        }
    }

    /// "Slack-4.35.126-arm64.dmg" matches an app named "Slack";
    /// "zoomusInstallerFull.pkg" matches "zoom.us"; "search-results.dmg"
    /// does not match "Arc".
    static func matchingApp(for url: URL, among appNames: [String]) -> String? {
        let base = url.deletingPathExtension().lastPathComponent.lowercased()
        let tokens = base
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let joined = tokens.joined()

        for name in appNames {
            let normalized = name.lowercased().filter { $0.isLetter || $0.isNumber }
            guard normalized.count >= 3 else { continue }
            if tokens.contains(normalized) || joined.hasPrefix(normalized) {
                return name
            }
        }
        return nil
    }
}
