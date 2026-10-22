import Foundation

@MainActor
final class AppsViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isScanning = false
    @Published var searchText = ""
    @Published var selection: URL?

    @Published var leftovers: [LeftoverItem] = []
    @Published var checkedLeftovers: Set<URL> = []
    @Published var isLoadingLeftovers = false

    @Published var failures: [Remover.Failure] = []
    @Published var statusMessage: String?

    var filteredApps: [InstalledApp] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.bundleID?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var selectedApp: InstalledApp? {
        apps.first { $0.url == selection }
    }

    var checkedLeftoverItems: [LeftoverItem] {
        leftovers.filter { checkedLeftovers.contains($0.url) }
    }

    var checkedLeftoverSize: Int64 {
        checkedLeftoverItems.reduce(0) { $0 + $1.size }
    }

    func refresh() async {
        isScanning = true
        let found = await Task.detached(priority: .userInitiated) {
            AppScanner.installedApps()
        }.value
        apps = found

        await withTaskGroup(of: (URL, Int64).self) { group in
            for app in found {
                group.addTask {
                    (app.url, DiskUsage.size(of: app.url))
                }
            }
            for await (url, size) in group {
                if let index = apps.firstIndex(where: { $0.url == url }) {
                    apps[index].size = size
                }
            }
        }
        isScanning = false
    }

    func loadLeftovers(for app: InstalledApp?) async {
        leftovers = []
        checkedLeftovers = []
        guard let app else {
            isLoadingLeftovers = false
            return
        }
        isLoadingLeftovers = true
        let found = await Task.detached(priority: .userInitiated) {
            LeftoverFinder.find(for: app)
        }.value
        // The user may have clicked another app while this one was scanning.
        guard selection == app.url else { return }
        leftovers = found
        checkedLeftovers = Set(found.map(\.url))
        isLoadingLeftovers = false
    }

    func uninstallSelected() {
        guard let app = selectedApp, !app.isSystemApp else { return }
        let leftoverURLs = checkedLeftoverItems.map(\.url)

        var failed: [Remover.Failure] = []
        if let failure = Remover.trash(app.url, finderFallback: true) {
            failed.append(failure)
        }
        for url in leftoverURLs {
            if let failure = Remover.trash(url, finderFallback: false) {
                failed.append(failure)
            }
        }

        let moved = 1 + leftoverURLs.count - failed.count
        statusMessage = "Moved \(moved) item\(moved == 1 ? "" : "s") to the Trash."
        failures = failed

        let appRemoved = !failed.contains { $0.url == app.url }
        if appRemoved {
            apps.removeAll { $0.url == app.url }
            selection = nil
            leftovers = []
            checkedLeftovers = []
        } else {
            let failedURLs = Set(failed.map(\.url))
            leftovers.removeAll { !failedURLs.contains($0.url) }
            checkedLeftovers = checkedLeftovers.intersection(failedURLs)
        }
    }
}
