import SwiftUI

/// The request list in whichever form the toolbar picked, with the quick modes, banners and empty states around it.
struct ConsoleContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if model.selectedSessionID != nil {
                QuickModeBar()
                Divider()
                ConsoleBanners()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    NewRequestsPill()
                }
                .animation(.snappy, value: model.unseenCount > 0)
        }
        .environment(\.searchHighlight, model.urlHighlight)
    }

    @ViewBuilder
    private var content: some View {
        let entries = model.visibleEntries
        if model.selectedSessionID == nil {
            ContentUnavailableView("No Session", systemImage: "iphone.slash",
                                   description: Text("Connect a device or open a .peek file."))
        } else if model.selectedEntries.isEmpty {
            ContentUnavailableView("No Requests Yet", systemImage: "network",
                                   description: Text("Requests from the app appear here as they happen."))
        } else if model.filteredEntries.isEmpty {
            if model.search.query.isEmpty {
                ContentUnavailableView {
                    Label("No Matches", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("No requests match the filters.")
                } actions: {
                    Button("Reset Filters") { model.filter = ConsoleFilter() }
                }
            } else {
                ContentUnavailableView.search(text: model.search.query)
            }
        } else if entries.isEmpty {
            ContentUnavailableView {
                Label("No \(model.quickMode.title) Requests", systemImage: "tray")
            } actions: {
                Button("Show All") { model.quickMode = .all }
            }
        } else {
            switch model.viewMode {
            case .table:
                ConsoleTableView(entries: entries)
            case .list:
                ConsoleListView(entries: entries)
            }
        }
    }
}

#Preview("Live") {
    ConsoleContentView()
        .environment(AppModel.preview(.live))
        .frame(width: 1000, height: 600)
}

#Preview("Paused — Dark") {
    ConsoleContentView()
        .environment(AppModel.preview(.paused))
        .frame(width: 1000, height: 600)
        .preferredColorScheme(.dark)
}
