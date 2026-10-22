import SwiftUI

struct CleanView: View {
    @ObservedObject var model: CleanViewModel
    @State private var isConfirming = false

    var body: some View {
        VStack(spacing: 0) {
            if model.categories.isEmpty && !model.isScanning {
                Text("Nothing to clean was found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.categories) { category in
                        CategoryRow(category: category, model: model)
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
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .disabled(model.isScanning || model.isCleaning)
                .help("Measure the junk again")
            }
        }
        .task {
            if model.categories.isEmpty {
                await model.scan()
            }
        }
        .confirmationDialog(
            model.checkedIncludesPermanent ? "Delete the selected items permanently?" : "Move the selected items to the Trash?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button(model.checkedIncludesPermanent ? "Delete" : "Move to Trash", role: .destructive) {
                Task { await model.clean() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(model.checkedItemCount) items, about \(DiskUsage.format(model.checkedSize)).")
        }
        .failureAlert($model.failures)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Delete permanently instead of moving to the Trash", isOn: $model.deletePermanently)
                Spacer()
                if model.isCleaning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Cleaning…")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Selected: \(DiskUsage.format(model.checkedSize))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Button {
                    isConfirming = true
                } label: {
                    Label("Clean selected", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.checked.isEmpty || model.isScanning || model.isCleaning)
            }
            if let message = model.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CategoryRow: View {
    let category: JunkCategory
    @ObservedObject var model: CleanViewModel

    private var result: JunkScanResult? {
        model.results[category.id]
    }

    private var isEmpty: Bool {
        (result?.size ?? 0) == 0 && result != nil
    }

    var body: some View {
        Toggle(isOn: isChecked) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(category.name)
                        if category.permanentOnly {
                            Text("permanent")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(category.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(category.displayPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if model.scanningIDs.contains(category.id) {
                    ProgressView()
                        .controlSize(.small)
                } else if let result {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(DiskUsage.format(result.size))
                            .monospacedDigit()
                        Text("\(result.items.count) item\(result.items.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .toggleStyle(.checkbox)
        .disabled(isEmpty || model.isCleaning)
    }

    private var isChecked: Binding<Bool> {
        Binding(
            get: { model.checked.contains(category.id) },
            set: { isOn in
                if isOn {
                    model.checked.insert(category.id)
                } else {
                    model.checked.remove(category.id)
                }
            }
        )
    }
}
