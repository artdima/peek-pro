import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @AppStorage(DetailPlacement.storageKey) private var detailPlacement: DetailPlacement = .bottom

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 380)
        } detail: {
            ConsoleSplitView(placement: detailPlacement)
        }
        .frame(minWidth: 960, minHeight: 600)
        .navigationTitle(model.windowTitle)
        .navigationSubtitle(model.windowSubtitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                DetailPlacementMenu(placement: $detailPlacement)
            }
        }
    }
}

#Preview("Live") {
    MainWindow()
        .environment(AppModel(store: MockStore(scenario: .live, isLive: false)))
        .frame(width: 1280, height: 800)
}

#Preview("Waiting — Dark") {
    MainWindow()
        .environment(AppModel(store: MockStore(scenario: .waiting, isLive: false)))
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
}
