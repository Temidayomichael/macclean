import AppKit
import Foundation

enum UpdateInstallError: LocalizedError {
    case badResponse(Int)
    case unzipFailed(String)
    case noAppInZip
    case wrongApp
    case notNewer(String)
    case swapFailed(String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            return "The download answered with status \(code)."
        case .unzipFailed(let message):
            return "The download could not be unpacked. \(message)"
        case .noAppInZip:
            return "The download does not contain an app."
        case .wrongApp:
            return "The download is not MacClean."
        case .notNewer(let version):
            return "The download is version \(version), which is not newer than this one."
        case .swapFailed(let message):
            return "The new version could not be put in place. \(message)"
        }
    }
}

/// Downloads a release zip, checks it, swaps it in for the running app and
/// relaunches. Files the app downloads itself carry no quarantine flag, so
/// the installed update opens without the right-click, Open step.
enum UpdateInstaller {
    /// True when the running copy is a real .app bundle that can be replaced
    /// (not `swift run`).
    static var canInstall: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    /// Downloads the zip into a fresh temporary folder, reporting progress from 0 to 1.
    static func download(from url: URL, progress: @escaping @MainActor (Double) -> Void) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("MacClean/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw UpdateInstallError.badResponse(status)
        }
        let expected = response.expectedContentLength
        if expected <= 0 {
            // No Content-Length: show the spinner rather than an empty bar.
            await progress(1)
        }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClean-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let zip = folder.appendingPathComponent("MacClean.zip")
        guard FileManager.default.createFile(atPath: zip.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: zip)
        defer { try? handle.close() }

        let chunk = 1 << 16
        var buffer = Data()
        buffer.reserveCapacity(chunk)
        var received: Int64 = 0
        var lastReport = Date.distantPast
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= chunk {
                try handle.write(contentsOf: buffer)
                received += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if expected > 0, Date().timeIntervalSince(lastReport) > 0.1 {
                    lastReport = Date()
                    await progress(min(1, Double(received) / Double(expected)))
                }
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }
        await progress(1)
        return zip
    }

    /// Unpacks the zip next to itself with ditto (what the release script zips with)
    /// and returns the app inside.
    static func unzip(_ zip: URL) async throws -> URL {
        let folder = zip.deletingLastPathComponent().appendingPathComponent("unpacked", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", zip.path, folder.path]
        let errors = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        // Drain stderr while ditto runs, so a long error can't fill the pipe and stall it.
        let errorOutput = Task.detached { errors.fileHandleForReading.readDataToEndOfFile() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        let data = await errorOutput.value
        guard process.terminationStatus == 0 else {
            let message = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdateInstallError.unzipFailed(message)
        }

        let items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        guard let app = items.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateInstallError.noAppInZip
        }
        return app
    }

    /// Makes sure the unpacked app is MacClean and newer than the running copy.
    static func validate(_ app: URL) throws {
        guard let bundle = Bundle(url: app),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateInstallError.wrongApp
        }
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard UpdateChecker.isNewer(version, than: AppInfo.version) else {
            throw UpdateInstallError.notNewer(version)
        }
    }

    /// Moves the running copy to the Trash and puts the new one at its path.
    /// If macOS refuses to move the old copy (it is owned by the system), the
    /// swap is done by a short shell script run with an administrator password
    /// instead; in that case the old copy is deleted rather than trashed.
    /// Whatever fails, the old copy is put back before the error is reported.
    @MainActor
    static func swapIn(_ newApp: URL) throws -> URL {
        let destination = Bundle.main.bundleURL
        let fm = FileManager.default

        // Keep whatever the installed copy is called, even if it was renamed.
        var source = newApp
        if newApp.lastPathComponent != destination.lastPathComponent {
            let renamed = newApp.deletingLastPathComponent().appendingPathComponent(destination.lastPathComponent)
            try fm.moveItem(at: newApp, to: renamed)
            source = renamed
        }

        var trashed: NSURL?
        do {
            try fm.trashItem(at: destination, resultingItemURL: &trashed)
        } catch {
            if let message = swapAsAdministrator(old: destination, new: source) {
                throw UpdateInstallError.swapFailed(message)
            }
            return destination
        }
        do {
            try fm.moveItem(at: source, to: destination)
        } catch {
            if let trashed {
                try? fm.moveItem(at: trashed as URL, to: destination)
            }
            throw UpdateInstallError.swapFailed(error.localizedDescription)
        }
        return destination
    }

    /// Quits and opens the new copy a moment later. Returns false, leaving the
    /// app running, if the helper that reopens it could not be started.
    @MainActor
    static func relaunch(_ app: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open -n \"$0\"", app.path]
        do {
            try process.run()
        } catch {
            return false
        }
        NSApp.terminate(nil)
        return true
    }

    /// Swaps the bundles as root after macOS asks for an administrator
    /// password. Finder can't be used here: it refuses to trash an app that
    /// is running, and this one is. Plain `mv` has no such rule. Returns an
    /// error message, or nil on success.
    private static func swapAsAdministrator(old: URL, new: URL) -> String? {
        func shellQuoted(_ path: String) -> String {
            "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        let shell = """
        old=\(shellQuoted(old.path)); new=\(shellQuoted(new.path)); backup="$old.previous"
        rm -rf "$backup" && mv "$old" "$backup" || exit 1
        if mv "$new" "$old"; then rm -rf "$backup"; else mv "$backup" "$old"; exit 1; fi
        """
        // One line, so the AppleScript string literal never spans lines.
        let appleScriptLiteral = shell
            .split(separator: "\n")
            .joined(separator: "; ")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(appleScriptLiteral)\" with administrator privileges"
        guard let script = NSAppleScript(source: source) else {
            return "Could not build the install script."
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            return (errorInfo[NSAppleScript.errorMessage] as? String) ?? "The administrator step was cancelled."
        }
        return nil
    }
}
