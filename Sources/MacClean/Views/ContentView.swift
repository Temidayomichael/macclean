import SwiftUI

struct ContentView: View {
    @StateObject private var appsModel = AppsViewModel()
    @StateObject private var cleanModel = CleanViewModel()

    var body: some View {
        TabView {
            AppsView(model: appsModel)
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
            CleanView(model: cleanModel)
                .tabItem { Label("Clean", systemImage: "sparkles") }
        }
        .frame(minWidth: 880, minHeight: 560)
    }
}

/// Shows the items that could not be removed, if any.
struct FailureAlert: ViewModifier {
    @Binding var failures: [Remover.Failure]

    func body(content: Content) -> some View {
        content.alert(
            "Some items could not be removed",
            isPresented: Binding(
                get: { !failures.isEmpty },
                set: { if !$0 { failures = [] } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(failures.prefix(6)
                .map { "\($0.url.lastPathComponent): \($0.message)" }
                .joined(separator: "\n")
                + (failures.count > 6 ? "\n…and \(failures.count - 6) more." : ""))
        }
    }
}

extension View {
    func failureAlert(_ failures: Binding<[Remover.Failure]>) -> some View {
        modifier(FailureAlert(failures: failures))
    }
}
