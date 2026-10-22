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
                    Text("You have version \(updates.currentVersion).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Later") {
                    updates.available = nil
                }
                Button("Download") {
                    NSWorkspace.shared.open(info.downloadURL ?? info.releaseURL)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.08))
            Divider()
        }
    }
}
