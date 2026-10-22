import Foundation

@MainActor
final class InstallersViewModel: ObservableObject {
    @Published var items: [InstallerFile] = []
    @Published var checked: Set<URL> = []
    @Published var isScanning = false
    @Published var isRemoving = false

    @Published var failures: [Remover.Failure] = []
    @Published var statusMessage: String?

    var checkedItems: [InstallerFile] {
        items.filter { checked.contains($0.url) }
    }

    var checkedSize: Int64 {
        checkedItems.reduce(0) { $0 + $1.size }
    }

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    func scan() async {
        isScanning = true
        let found = await Task.detached(priority: .userInitiated) {
            InstallerScanner.find()
        }.value
        items = found
        // Installers for apps that are already installed are safe to pre-select.
        checked = Set(found.filter { $0.installedAppName != nil }.map(\.url))
        isScanning = false
    }

    func trashChecked() async {
        guard !isRemoving else { return }
        isRemoving = true
        let targets = checkedItems.map(\.url)
        let expectedBytes = checkedSize

        let failed = await Task.detached(priority: .userInitiated) { () -> [Remover.Failure] in
            targets.compactMap { Remover.trash($0, finderFallback: false) }
        }.value

        failures = failed
        let failedURLs = Set(failed.map(\.url))
        let targetURLs = Set(targets)
        items.removeAll { targetURLs.contains($0.url) && !failedURLs.contains($0.url) }
        checked = checked.intersection(failedURLs)

        let moved = targets.count - failed.count
        statusMessage = "Moved \(moved) installer\(moved == 1 ? "" : "s") to the Trash, about \(DiskUsage.format(expectedBytes))."
        isRemoving = false
    }
}
