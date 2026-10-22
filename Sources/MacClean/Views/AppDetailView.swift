import AppKit
import SwiftUI

struct AppDetailView: View {
    let app: InstalledApp
    @ObservedObject var model: AppsViewModel
    @State private var isConfirming = false

    private var totalSize: Int64 {
        (app.size ?? 0) + model.checkedLeftoverSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            leftovers
            footer
        }
        .padding(20)
        .confirmationDialog(
            "Move \"\(app.name)\" to the Trash?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                model.uninstallSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let count = model.checkedLeftoverItems.count
            Text("The app and \(count) related item\(count == 1 ? "" : "s") (\(DiskUsage.format(totalSize))) will be moved to the Trash. You can put them back from the Trash.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.title2)
                    .bold()
                if let version = app.version {
                    Text("Version \(version)")
                        .foregroundStyle(.secondary)
                }
                Text(app.bundleID ?? "No bundle identifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(PathDisplay.abbreviate(app.url))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(app.size.map(DiskUsage.format) ?? "—")
                    .font(.title3)
                    .monospacedDigit()
                Text("app size")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var leftovers: some View {
        HStack {
            Text("Related files")
                .font(.headline)
            if !model.leftovers.isEmpty {
                Text("\(model.leftovers.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !model.leftovers.isEmpty {
                Button("Select all") {
                    model.checkedLeftovers = Set(model.leftovers.map(\.url))
                }
                .buttonStyle(.link)
                Button("Select none") {
                    model.checkedLeftovers = []
                }
                .buttonStyle(.link)
            }
        }

        if model.isLoadingLeftovers {
            ProgressView("Looking through your Library folder…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.leftovers.isEmpty {
            Text("No leftover files found in your Library folder.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(model.leftovers) { item in
                Toggle(isOn: isChecked(item)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayPath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(item.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(DiskUsage.format(item.size))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .contextMenu {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private var footer: some View {
        HStack {
            if app.isSystemApp {
                Label("Apps made by Apple are protected by macOS and can't be removed.", systemImage: "lock")
                    .foregroundStyle(.secondary)
            } else {
                Text("Will free about \(DiskUsage.format(totalSize))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }
            Button(role: .destructive) {
                isConfirming = true
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(app.isSystemApp || model.isLoadingLeftovers)
        }
    }

    private func isChecked(_ item: LeftoverItem) -> Binding<Bool> {
        Binding(
            get: { model.checkedLeftovers.contains(item.url) },
            set: { isOn in
                if isOn {
                    model.checkedLeftovers.insert(item.url)
                } else {
                    model.checkedLeftovers.remove(item.url)
                }
            }
        )
    }
}
