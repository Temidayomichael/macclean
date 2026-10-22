import Foundation

enum AppInfo {
    /// Version from Info.plist, or the fallback when run without a bundle (`swift run`).
    static let version: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"

    static let repositoryURL = URL(string: "https://github.com/Temidayomichael/macclean")!
    static let releasesURL = URL(string: "https://github.com/Temidayomichael/macclean/releases")!
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/Temidayomichael/macclean/releases/latest")!
}
