import AppKit
import SwiftUI

/// Shown above the tabs when a newer release exists.
struct UpdateBanner: View {
    @EnvironmentObject private var updates: UpdateChecker

    var body: some View {
        if let info = updates.available {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MacClean \(info.version) is available")
                        .font(.headline)
                    Text(updates.installStage ?? "You have version \(updates.currentVersion).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let progress = updates.installProgress {
                    if progress < 1 {
                        ProgressView(value: progress)
                            .frame(width: 160)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                } else {
                    Button("Later") {
                        updates.available = nil
                    }
                    if updates.canInstall, info.downloadURL != nil {
                        Button("Download") {
                            NSWorkspace.shared.open(info.downloadURL ?? info.releaseURL)
                        }
                        Button("Install Update") {
                            Task { await updates.install(info) }
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Downloads MacClean \(info.version), replaces this copy and reopens it")
                    } else {
                        Button("Download") {
                            NSWorkspace.shared.open(info.downloadURL ?? info.releaseURL)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.08))
            Divider()
        }
    }
}
