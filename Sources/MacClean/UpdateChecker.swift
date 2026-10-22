import Foundation

struct UpdateInfo: Equatable {
    let version: String
    let releaseURL: URL
    /// The MacClean.zip asset, when the release has one.
    let downloadURL: URL?
}

enum UpdateError: LocalizedError {
    case noReleases
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .noReleases:
            return "No releases have been published yet."
        case .badResponse(let code):
            return "GitHub answered with status \(code)."
        }
    }
}

/// Checks GitHub Releases for a newer MacClean. The only data sent is the
/// request itself; nothing about your Mac is included.
@MainActor
final class UpdateChecker: ObservableObject {
    static let automaticKey = "automaticUpdateChecks"
    private static let lastCheckKey = "lastUpdateCheck"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    @Published var available: UpdateInfo?
    @Published var isChecking = false
    /// Outcome of a manual check, shown in an alert.
    @Published var manualResult: String?

    var currentVersion: String { AppInfo.version }

    /// Called at launch: checks at most once a day, and only if the
    /// "Check for Updates Automatically" menu item is on.
    func checkAutomaticallyIfDue() async {
        let defaults = UserDefaults.standard
        let enabled = (defaults.object(forKey: Self.automaticKey) as? Bool) ?? true
        guard enabled else { return }
        let last = defaults.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > Self.checkInterval else { return }
        await check(manual: false)
    }

    func check(manual: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            let info = try await Self.fetchLatest()
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
            if Self.isNewer(info.version, than: currentVersion) {
                available = info
            } else {
                available = nil
                if manual {
                    manualResult = "MacClean \(currentVersion) is the latest version."
                }
            }
        } catch {
            if manual {
                manualResult = "Could not check for updates. \(error.localizedDescription)"
            }
        }
    }

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }

    nonisolated private static func fetchLatest() async throws -> UpdateInfo {
        var request = URLRequest(url: AppInfo.latestReleaseAPI)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MacClean/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 {
            throw UpdateError.noReleases
        }
        guard (200..<300).contains(status) else {
            throw UpdateError.badResponse(status)
        }

        let release = try JSONDecoder().decode(Release.self, from: data)
        let version = release.tag_name.hasPrefix("v")
            ? String(release.tag_name.dropFirst())
            : release.tag_name
        let zip = release.assets.first { $0.name.lowercased().hasSuffix(".zip") }?.browser_download_url
        return UpdateInfo(version: version, releaseURL: release.html_url, downloadURL: zip)
    }

    /// "1.2.0" is newer than "1.1.9"; "1.2" equals "1.2.0".
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        func numbers(_ version: String) -> [Int] {
            version.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = numbers(candidate)
        let b = numbers(current)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }
}
