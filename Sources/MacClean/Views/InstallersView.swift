import AppKit
import SwiftUI

struct InstallersView: View {
    @ObservedObject var model: InstallersViewModel
    @State private var isConfirming = false

    var body: some View {
        VStack(spacing: 0) {
            if model.isScanning && model.items.isEmpty {
                ProgressView("Looking for installers…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.items.isEmpty {
                emptyState
            } else {
                List(model.items) { item in
                    InstallerRow(item: item, isChecked: isChecked(item))
                        .contextMenu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                        }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            Divider()
            footer
                .padding()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await model.scan() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(model.isScanning || model.isRemoving)
                .help("Look for installers again")
            }
        }
        .task {
            if model.items.isEmpty {
                await model.scan()
            }
        }
        .confirmationDialog(
            "Move \(model.checkedItems.count) installer\(model.checkedItems.count == 1 ? "" : "s") to the Trash?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                Task { await model.trashChecked() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("About \(DiskUsage.format(model.checkedSize)) will be moved to the Trash. You can put the files back from there.")
        }
        .failureAlert($model.failures)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No installers found")
                .font(.title3)
            Text("MacClean looks for .dmg, .pkg and .xip files in your Downloads and Desktop folders.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let message = model.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(model.items.count) installer\(model.items.count == 1 ? "" : "s"), \(DiskUsage.format(model.totalSize)) in total")
                    .foregroundStyle(.secondary)
                if !model.items.isEmpty {
                    Button("Select all") {
                        model.checked = Set(model.items.map(\.url))
                    }
                    .buttonStyle(.link)
                    Button("Select none") {
                        model.checked = []
                    }
                    .buttonStyle(.link)
                }
                Spacer()
                if model.isRemoving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Selected: \(DiskUsage.format(model.checkedSize))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    isConfirming = true
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(model.checked.isEmpty || model.isScanning || model.isRemoving)
            }
            if let message = model.statusMessage, !model.items.isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func isChecked(_ item: InstallerFile) -> Binding<Bool> {
        Binding(
            get: { model.checked.contains(item.url) },
            set: { isOn in
                if isOn {
                    model.checked.insert(item.url)
                } else {
                    model.checked.remove(item.url)
                }
            }
        )
    }
}

struct InstallerRow: View {
    let item: InstallerFile
    @Binding var isChecked: Bool

    var body: some View {
        Toggle(isOn: $isChecked) {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.fileName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let app = item.installedAppName {
                            Text("Installed as \(app)")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.18), in: Capsule())
                        }
                    }
                    Text("\(item.folder)  ·  \(item.modified.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(DiskUsage.format(item.size))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .toggleStyle(.checkbox)
    }
}
