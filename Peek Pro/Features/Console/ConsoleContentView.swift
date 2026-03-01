import SwiftUI

/// The request list in whichever form the toolbar picked, with the empty states around it.
struct ConsoleContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let entries = model.filteredEntries
        Group {
            if model.selectedSessionID == nil {
                ContentUnavailableView("No Session", systemImage: "iphone.slash",
                                       description: Text("Connect a device or open a .peek file."))
            } else if model.selectedEntries.isEmpty {
                ContentUnavailableView("No Requests Yet", systemImage: "network",
                                       description: Text("Requests from the app appear here as they happen."))
            } else if entries.isEmpty {
                if model.searchText.isEmpty {
                    ContentUnavailableView("No Matches", systemImage: "line.3.horizontal.decrease.circle",
                                           description: Text("No requests match the filters."))
                } else {
                    ContentUnavailableView.search(text: model.searchText)
                }
            } else {
                switch model.viewMode {
                case .table:
                    ConsoleTableView(entries: entries)
                case .list:
                    ContentUnavailableView(ConsoleViewMode.list.title, systemImage: ConsoleViewMode.list.symbol)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
