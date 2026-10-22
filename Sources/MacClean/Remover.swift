import Foundation

enum Remover {
    struct Failure: Identifiable {
        let id = UUID()
        let url: URL
        let message: String
    }

    /// Moves an item to the Trash. Returns nil on success.
    ///
    /// Apps in /Applications are often owned by the system and `FileManager`
    /// can't move them. When `finderFallback` is set, Finder is asked to do it
    /// instead, which lets macOS prompt for an administrator password.
    /// Must be called on the main thread when `finderFallback` is true.
    static func trash(_ url: URL, finderFallback: Bool) -> Failure? {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return nil
        } catch {
            guard finderFallback else {
                return Failure(url: url, message: error.localizedDescription)
            }
            if let finderError = trashWithFinder(url) {
                return Failure(url: url, message: finderError)
            }
            return nil
        }
    }

    /// Deletes an item permanently. Returns nil on success.
    static func delete(_ url: URL) -> Failure? {
        do {
            try FileManager.default.removeItem(at: url)
            return nil
        } catch {
            return Failure(url: url, message: error.localizedDescription)
        }
    }

    private static func trashWithFinder(_ url: URL) -> String? {
        let escaped = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "tell application \"Finder\" to delete (POSIX file \"\(escaped)\" as alias)"
        guard let script = NSAppleScript(source: source) else {
            return "Could not build the Finder script."
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            return (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Finder could not move the item."
        }
        return nil
    }
}
