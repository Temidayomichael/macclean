import Foundation

@MainActor
final class CleanViewModel: ObservableObject {
    @Published var categories: [JunkCategory] = []
    @Published var results: [String: JunkScanResult] = [:]
    @Published var checked: Set<String> = []
    @Published var scanningIDs: Set<String> = []
    @Published var isCleaning = false
    @Published var deletePermanently = false

    @Published var failures: [Remover.Failure] = []
    @Published var statusMessage: String?

    var isScanning: Bool { !scanningIDs.isEmpty }

    var checkedSize: Int64 {
        checked.compactMap { results[$0]?.size }.reduce(0, +)
    }

    var checkedItemCount: Int {
        checked.compactMap { results[$0]?.items.count }.reduce(0, +)
    }

    var checkedIncludesPermanent: Bool {
        deletePermanently || categories.contains { checked.contains($0.id) && $0.permanentOnly }
    }

    func scan() async {
        let found = JunkScanner.categories()
        categories = found
        results = [:]
        scanningIDs = Set(found.map(\.id))

        await withTaskGroup(of: JunkScanResult.self) { group in
            for category in found {
                group.addTask {
                    JunkScanner.scan(category)
                }
            }
            for await result in group {
                results[result.id] = result
                scanningIDs.remove(result.id)
            }
        }

        // Pre-select everything that is safe to clean and not empty.
        checked = Set(found
            .filter { !$0.permanentOnly && (results[$0.id]?.size ?? 0) > 0 }
            .map(\.id))
    }

    func clean() async {
        guard !isCleaning else { return }
        isCleaning = true

        var targets: [(url: URL, permanent: Bool)] = []
        for category in categories where checked.contains(category.id) {
            guard let result = results[category.id] else { continue }
            let permanent = deletePermanently || category.permanentOnly
            targets.append(contentsOf: result.items.map { (url: $0, permanent: permanent) })
        }
        let expectedBytes = checkedSize
        let work = targets

        let failed = await Task.detached(priority: .userInitiated) { () -> [Remover.Failure] in
            var failures: [Remover.Failure] = []
            for target in work {
                let failure = target.permanent
                    ? Remover.delete(target.url)
                    : Remover.trash(target.url, finderFallback: false)
                if let failure {
                    failures.append(failure)
                }
            }
            return failures
        }.value

        failures = failed
        let removed = work.count - failed.count
        let verb = checkedIncludesPermanent ? "Removed" : "Moved"
        let suffix = checkedIncludesPermanent ? "" : " to the Trash"
        statusMessage = "\(verb) \(removed) item\(removed == 1 ? "" : "s")\(suffix), about \(DiskUsage.format(expectedBytes))."
        isCleaning = false

        await scan()
    }
}
