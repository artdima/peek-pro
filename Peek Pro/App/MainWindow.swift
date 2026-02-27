import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @AppStorage(DetailPlacement.storageKey) private var detailPlacement: DetailPlacement = .bottom
    @State private var isConfirmingClear = false

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 380)
        } detail: {
            ConsoleSplitView(placement: detailPlacement)
        }
        .frame(minWidth: 1024, minHeight: 600)
        .navigationTitle(model.windowTitle)
        .navigationSubtitle(model.windowSubtitle)
        .toolbar(removing: .title)
        .toolbar {
            ConsoleToolbar(model: model, detailPlacement: $detailPlacement, isConfirmingClear: $isConfirmingClear)
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search")
        .confirmationDialog(
            "Clear all requests from \(model.windowTitle)?",
            isPresented: $isConfirmingClear
        ) {
            Button("Clear", role: .destructive) {
                if let id = model.selectedSessionID { model.store.clear(id) }
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
