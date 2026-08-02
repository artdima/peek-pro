import AppKit
import SwiftUI

/// The lower (or right) half of the console: one request, or what to do with several.
struct RequestDetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let entry = model.selectedEntry {
                EntryDetailView(entry: entry)
            } else if model.selectedEntryIDs.count > 1 {
                MultipleSelectionView(entries: model.commandEntries)
            } else {
                ContentUnavailableView("No Request Selected", systemImage: "network",
                                       description: Text("Select a request to see its details."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EntryDetailView: View {
    let entry: PeekEntry
    /// In its own window there is no split to rearrange and nothing to detach.
    var isStandalone = false

    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @SceneStorage("detailTab") private var selectedTab: DetailTab = .summary

    var body: some View {
        let tabs = DetailTab.available(for: entry)
        let tab = tabs.contains(selectedTab) ? selectedTab : .summary
        VStack(spacing: 0) {
            DetailHeader(tabs: tabs, selection: tab, showsWindowControls: !isStandalone, select: { selectedTab = $0 }) {
                OpenEntryWindowsAction(model: model, openWindow: openWindow)([entry.id])
            }
            Divider()
            Group {
                switch tab {
                case .summary:
                    SummaryTab(entry: entry) { selectedTab = $0 }
                case .request:
                    BodyTab(entry: entry, side: .request)
                case .response:
                    BodyTab(entry: entry, side: .response)
                case .headers:
                    HeadersTab(entry: entry)
                case .cookies:
                    CookiesTab(entry: entry)
                case .error:
                    ErrorTab(entry: entry) { selectedTab = $0 }
                case .curl:
                    CurlTab(entry: entry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct DetailHeader: View {
    let tabs: [DetailTab]
    let selection: DetailTab
    let showsWindowControls: Bool
    let select: (DetailTab) -> Void
    let openInWindow: () -> Void

    @AppStorage(DetailPlacement.storageKey) private var placement: DetailPlacement = .bottom

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                PillButton(title: tab.title, isSelected: tab == selection) { select(tab) }
            }
            Spacer(minLength: 12)
            if showsWindowControls {
                windowControls
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var windowControls: some View {
        HStack(spacing: 10) {
            Button(action: openInWindow) {
                Label("Open in New Window", systemImage: "macwindow.on.rectangle")
            }
            .help("Open in a new window")

            Button {
                placement = placement == .right ? .bottom : .right
            } label: {
                Label(placement == .right ? "Details at Bottom" : "Details on Right",
                      systemImage: placement == .right ? DetailPlacement.bottom.symbol : DetailPlacement.right.symbol)
            }
            .help(placement == .right ? "Move details to the bottom" : "Move details to the right")

            Button {
                placement = .hidden
            } label: {
                Label("Hide Details", systemImage: "xmark")
            }
            .help("Hide details")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }
}

private struct MultipleSelectionView: View {
    @Environment(AppModel.self) private var model
    let entries: [PeekEntry]

    var body: some View {
        ContentUnavailableView {
            Label("\(entries.count) Requests Selected", systemImage: "square.stack.3d.up")
        } description: {
            Text(summary)
        } actions: {
            HStack {
                Button("Copy URLs") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entries.map(\.request.uri.absoluteString).joined(separator: "\n"), forType: .string)
                }
                Button(entries.allSatisfy(\.isPinned) ? "Unpin All" : "Pin All") {
                    model.togglePin(Set(entries.map(\.id)))
                }
                Button("Export as HAR…") {
                    model.exportHAR(entries)
                }
            }
        }
    }

    private var summary: String {
        let errors = entries.filter(\.isError).count
        let bytes = entries.reduce(0) { $0 + ($1.totalSize ?? 0) }
        return "\(errors) with errors · \(PeekFormat.bytes(bytes)) in total"
    }
}

#Preview("Success") {
    EntryDetailView(entry: Fixtures.entry("f01"))
        .environment(AppModel.preview(.live))
        .frame(width: 1000, height: 420)
}

#Preview("Failure — Dark") {
    EntryDetailView(entry: Fixtures.entry("f12"))
        .environment(AppModel.preview(.live))
        .frame(width: 1000, height: 420)
        .preferredColorScheme(.dark)
}

#Preview("Several") {
    let model = AppModel.preview(.live)
    model.selectedEntryIDs = [PeekId("f01"), PeekId("f03"), PeekId("f10")]
    return RequestDetailView()
        .environment(model)
        .frame(width: 1000, height: 420)
}

#Preview("Nothing") {
    RequestDetailView()
        .environment(AppModel.preview(.live))
        .frame(width: 1000, height: 420)
}
