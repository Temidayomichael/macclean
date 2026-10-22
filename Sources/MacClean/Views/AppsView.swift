import SwiftUI

struct AppsView: View {
    @ObservedObject var model: AppsViewModel

    var body: some View {
        NavigationSplitView {
            List(model.filteredApps, selection: $model.selection) { app in
                AppRow(app: app)
            }
            .searchable(text: $model.searchText, placement: .sidebar, prompt: "Search apps")
            .navigationSplitViewColumnWidth(min: 260, ideal: 320)
            .overlay {
                if model.apps.isEmpty && model.isScanning {
                    ProgressView("Scanning applications…")
                }
            }
        } detail: {
            if let app = model.selectedApp {
                AppDetailView(app: app, model: model)
            } else {
                placeholder
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(model.isScanning)
                .help("Scan the Applications folders again")
            }
        }
        .task {
            if model.apps.isEmpty {
                await model.refresh()
            }
        }
        .onChange(of: model.selection) { _ in
            Task { await model.loadLeftovers(for: model.selectedApp) }
        }
        .failureAlert($model.failures)
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Select an app to see what it leaves behind")
                .font(.title3)
            Text("\(model.apps.count) apps found")
                .foregroundStyle(.secondary)
            if let message = model.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .lineLimit(1)
                Text(app.bundleID ?? app.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let size = app.size {
                Text(DiskUsage.format(size))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}
