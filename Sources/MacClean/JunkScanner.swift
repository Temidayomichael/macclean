import Foundation

enum JunkScanner {
    /// Junk categories whose folder exists on this Mac.
    static func categories() -> [JunkCategory] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        func path(_ relative: String) -> URL {
            home.appendingPathComponent(relative, isDirectory: true)
        }

        let all: [JunkCategory] = [
            JunkCategory(
                id: "caches",
                name: "User caches",
                detail: "Caches apps keep in your Library folder. Apps rebuild them when needed.",
                url: path("Library/Caches"),
                mode: .children,
                permanentOnly: false
            ),
            JunkCategory(
                id: "logs",
                name: "Log files",
                detail: "Application logs and crash reports.",
                url: path("Library/Logs"),
                mode: .children,
                permanentOnly: false
            ),
            JunkCategory(
                id: "derived-data",
                name: "Xcode DerivedData",
                detail: "Build products and indexes. Xcode regenerates them on the next build.",
                url: path("Library/Developer/Xcode/DerivedData"),
                mode: .children,
                permanentOnly: false
            ),
            JunkCategory(
                id: "device-support",
                name: "iOS device support",
                detail: "Debug symbols Xcode downloaded for connected devices. Re-downloaded when a device is plugged in.",
                url: path("Library/Developer/Xcode/iOS DeviceSupport"),
                mode: .children,
                permanentOnly: false
            ),
            JunkCategory(
                id: "simulator-caches",
                name: "Simulator caches",
                detail: "Caches for the iOS Simulator.",
                url: path("Library/Developer/CoreSimulator/Caches"),
                mode: .children,
                permanentOnly: false
            ),
            JunkCategory(
                id: "npm-cache",
                name: "npm cache",
                detail: "Packages npm downloaded. They are fetched again on the next install.",
                url: path(".npm/_cacache"),
                mode: .children,
                permanentOnly: false
            ),
            JunkCategory(
                id: "gradle-caches",
                name: "Gradle caches",
                detail: "Dependencies and build caches used by Gradle and Android Studio.",
                url: path(".gradle/caches"),
                mode: .children,
                permanentOnly: false
            ),
            JunkCategory(
                id: "trash",
                name: "Trash",
                detail: "Empties your Trash. This cannot be undone.",
                url: path(".Trash"),
                mode: .children,
                permanentOnly: true
            ),
        ]

        return all.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    static func scan(_ category: JunkCategory) -> JunkScanResult {
        let items: [URL]
        switch category.mode {
        case .children:
            items = (try? FileManager.default.contentsOfDirectory(
                at: category.url,
                includingPropertiesForKeys: nil,
                options: []
            )) ?? []
        case .whole:
            items = [category.url]
        }
        let size = items.reduce(Int64(0)) { $0 + DiskUsage.size(of: $1) }
        return JunkScanResult(category: category, items: items, size: size)
    }
}
