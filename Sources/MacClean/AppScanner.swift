import Foundation

enum AppScanner {
    static var searchDirectories: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    /// Apps in /Applications and ~/Applications, including one level of
    /// subfolders (for example /Applications/Utilities).
    static func installedApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        var seen: Set<URL> = []

        func append(_ url: URL) {
            let standardized = url.standardizedFileURL
            guard !seen.contains(standardized) else { return }
            seen.insert(standardized)
            apps.append(makeApp(standardized))
        }

        for directory in searchDirectories {
            for url in contents(of: directory) {
                if url.pathExtension == "app" {
                    append(url)
                } else if url.hasDirectoryPath {
                    for nested in contents(of: url) where nested.pathExtension == "app" {
                        append(nested)
                    }
                }
            }
        }

        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func contents(of directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    private static func makeApp(_ url: URL) -> InstalledApp {
        let info = Bundle(url: url)?.infoDictionary ?? [:]
        let fileName = url.deletingPathExtension().lastPathComponent
        let bundleName = info["CFBundleName"] as? String
        let version = (info["CFBundleShortVersionString"] as? String)
            ?? (info["CFBundleVersion"] as? String)
        return InstalledApp(
            url: url,
            name: fileName,
            bundleName: bundleName == fileName ? nil : bundleName,
            bundleID: info["CFBundleIdentifier"] as? String,
            version: version,
            size: nil
        )
    }
}
