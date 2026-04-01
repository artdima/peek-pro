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
                MultipleSelectionView(entries: model.selectedEntries.filter { model.selectedEntryIDs.contains($0.id) })
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

    @SceneStorage("detailTab") private var selectedTab: DetailTab = .summary

    var body: some View {
        let tabs = DetailTab.available(for: entry)
        let tab = tabs.contains(selectedTab) ? selectedTab : .summary
        VStack(spacing: 0) {
            DetailHeader(tabs: tabs, selection: tab) { selectedTab = $0 }
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
                default:
                    DetailTabContent(entry: entry, tab: tab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct DetailHeader: View {
    let tabs: [DetailTab]
    let selection: DetailTab
    let select: (DetailTab) -> Void

    @AppStorage(DetailPlacement.storageKey) private var placement: DetailPlacement = .bottom

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                PillButton(title: tab.title, isSelected: tab == selection) { select(tab) }
            }
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                Button {
                } label: {
                    Label("Open in New Window", systemImage: "macwindow.on.rectangle")
                }
                .disabled(true)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// Stand-ins until each tab gets its own view.
private struct DetailTabContent: View {
    let entry: PeekEntry
    let tab: DetailTab

    var body: some View {
        ContentUnavailableView {
            Label(tab.title, systemImage: tab.symbol)
        } description: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    StatusIcon(entry: entry)
                    StatusLabel(entry: entry)
                    if let duration = entry.duration {
                        Text(PeekFormat.duration(duration))
                            .monospacedDigit()
                    }
                }
                Text("\(entry.request.method) \(entry.request.uri.absoluteString)")
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
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
                    guard let sessionID = model.selectedSessionID else { return }
                    let allPinned = entries.allSatisfy(\.isPinned)
                    for entry in entries where entry.isPinned == allPinned {
                        model.store.togglePin(entry.id, in: sessionID)
                    }
                }
                Button("Export as HAR…") {}
                    .disabled(true)
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
