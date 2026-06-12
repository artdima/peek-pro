import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @AppStorage(DetailPlacement.storageKey) private var detailPlacement: DetailPlacement = .bottom

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 290, max: 400)
        } detail: {
            ConsoleSplitView(placement: detailPlacement)
        }
        .frame(minWidth: 1024, minHeight: 600)
        .navigationTitle(model.windowTitle)
        .navigationSubtitle(model.windowSubtitle)
        .toolbar(removing: .title)
        .toolbar {
            ConsoleToolbar(model: model, detailPlacement: $detailPlacement, isConfirmingClear: $model.isConfirmingClear)
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search")
        .searchScopes($model.searchScope) {
            ForEach(ConsoleSearchScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let sessions = urls.filter { $0.pathExtension.lowercased() == "peek" }
            guard !sessions.isEmpty else { return false }
            model.open(sessions)
            return true
        }
        .alert(
            model.fileOpenError.map { "Can't Open “\($0.name)”" } ?? "",
            isPresented: Binding(
                get: { model.fileOpenError != nil },
                set: { if !$0 { model.fileOpenError = nil } }
            ),
            presenting: model.fileOpenError
        ) { _ in
            Button("OK") {}
        } message: { error in
            Text(error.message)
        }
        .confirmationDialog(
            "Clear all requests from \(model.windowTitle)?",
            isPresented: $model.isConfirmingClear
        ) {
            Button("Clear", role: .destructive) {
                model.clearSelectedSession()
            }
        } message: {
            Text("New requests from the device keep arriving.")
        }
    }
}

#Preview("Live") {
    MainWindow()
        .environment(AppModel.preview(.live))
        .frame(width: 1280, height: 800)
}

#Preview("Waiting — Dark") {
    MainWindow()
        .environment(AppModel.preview(.waiting))
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
}
