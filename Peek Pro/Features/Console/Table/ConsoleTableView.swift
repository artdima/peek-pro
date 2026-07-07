import AppKit
import SwiftUI

struct ConsoleTableView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    let entries: [PeekEntry]

    @SceneStorage("consoleTable.sort") private var sortStorage = ConsoleSort.default.storage
    @SceneStorage("consoleTable.columns") private var columns = TableColumnCustomization<PeekEntry>()

    var body: some View {
        @Bindable var model = model
        let sort = ConsoleSort(storage: sortStorage) ?? .default
        let rows = sort.apply(entries)
        let newest = entries.max { $0.startedAt < $1.startedAt }?.id

        ScrollViewReader { proxy in
            Table(of: PeekEntry.self, selection: $model.selectedEntryIDs, sortOrder: sortOrder, columnCustomization: $columns) {
                Group {
                    TableColumn("", sortUsing: ConsoleSort(.status)) { entry in
                        StatusIcon(entry: entry)
                    }
                    .width(18)
                    .customizationID("status")
                    .disabledCustomizationBehavior(.visibility)

                    TableColumn("Code", sortUsing: ConsoleSort(.status)) { entry in
                        CodeCell(entry: entry)
                    }
                    .width(min: 36, ideal: 44, max: 64)
                    .customizationID("code")

                    TableColumn("Method", sortUsing: ConsoleSort(.method)) { entry in
                        ErrorTintedText(entry: entry, text: entry.request.method)
                    }
                    .width(min: 44, ideal: 60, max: 90)
                    .customizationID("method")

                    TableColumn("URL", sortUsing: ConsoleSort(.url)) { entry in
                        URLCell(entry: entry)
                    }
                    .width(min: 180, ideal: 420)
                    .customizationID("url")
                    .disabledCustomizationBehavior(.visibility)

                    TableColumn("Date", sortUsing: ConsoleSort(.startedAt)) { entry in
                        Text(PeekFormat.date(entry.startedAt))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 70, ideal: 96)
                    .customizationID("date")
                    .defaultVisibility(.hidden)

                    TableColumn("Time", sortUsing: ConsoleSort(.startedAt)) { entry in
                        Text(PeekFormat.time(entry.startedAt))
                            .monospacedDigit()
                    }
                    .width(min: 84, ideal: 96)
                    .customizationID("time")
                }
                Group {
                    TableColumn("Duration", sortUsing: ConsoleSort(.duration)) { entry in
                        DurationCell(entry: entry)
                    }
                    .width(min: 56, ideal: 72)
                    .alignment(.trailing)
                    .customizationID("duration")

                    TableColumn("Request", sortUsing: ConsoleSort(.requestSize)) { entry in
                        SizeCell(size: entry.requestSize)
                    }
                    .width(min: 52, ideal: 68)
                    .alignment(.trailing)
                    .customizationID("request")

                    TableColumn("Response", sortUsing: ConsoleSort(.responseSize)) { entry in
                        SizeCell(size: entry.responseSize)
                    }
                    .width(min: 56, ideal: 76)
                    .alignment(.trailing)
                    .customizationID("response")

                    TableColumn("Source", sortUsing: ConsoleSort(.source)) { entry in
                        Text(entry.source)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 44, ideal: 72)
                    .customizationID("source")

                    TableColumn("", sortUsing: ConsoleSort(.pinned)) { entry in
                        if entry.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.orange)
                                .help("Pinned")
                        }
                    }
                    .width(16)
                    .customizationID("pin")
                }
            } rows: {
                ForEach(rows) { entry in
                    TableRow(entry)
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .opensEntryWindows(model: model, openWindow: openWindow)
            .onChange(of: newest) { _, newest in
                guard model.isFollowing, let newest else { return }
                withAnimation { proxy.scrollTo(newest, anchor: sort == .default ? .bottom : nil) }
            }
            .onChange(of: model.scrollToLatestRequest) {
                guard let newest else { return }
                withAnimation { proxy.scrollTo(newest, anchor: sort == .default ? .bottom : nil) }
            }
        }
    }

    /// Only the first comparator counts: the table keeps earlier clicks behind it, and `PeekSort` is stable anyway.
    private var sortOrder: Binding<[ConsoleSort]> {
        Binding {
            [ConsoleSort(storage: sortStorage) ?? .default]
        } set: { order in
            sortStorage = (order.first ?? .default).storage
        }
    }
}

private struct ErrorTintedText: View {
    let entry: PeekEntry
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(entry.isError ? Color(.statusFailure) : Color.primary)
    }
}

private struct CodeCell: View {
    let entry: PeekEntry

    var body: some View {
        Text(entry.statusCode.map(String.init) ?? "—")
            .monospacedDigit()
            .foregroundStyle(entry.isError ? Color(.statusFailure) : Color.primary)
    }
}

private struct URLCell: View {
    let entry: PeekEntry
    @Environment(\.searchHighlight) private var highlight

    var body: some View {
        Text(attributedURL)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(entry.request.uri.absoluteString)
    }

    private var attributedURL: AttributedString {
        let request = entry.request
        var origin = AttributedString("\(request.uri.scheme ?? "https")://\(request.host)")
        var rest = AttributedString(request.path + (request.query.map { "?\($0)" } ?? ""))
        if entry.isError {
            origin.foregroundColor = Color(.statusFailure)
            rest.foregroundColor = Color(.statusFailure)
        } else {
            origin.foregroundColor = Color.secondary
        }
        var url = origin + rest
        url.highlight(highlight)
        return url
    }
}

private struct DurationCell: View {
    let entry: PeekEntry

    var body: some View {
        if entry.state == .pending {
            Text("…")
                .foregroundStyle(.secondary)
        } else {
            Text(entry.duration.map { PeekFormat.duration($0) } ?? "—")
                .monospacedDigit()
                .foregroundStyle((entry.duration?.timeInterval ?? 0) >= ConsoleIssue.slowThreshold ? Color.orange : Color.primary)
        }
    }
}

private struct SizeCell: View {
    let size: Int?

    var body: some View {
        Text(size.map { PeekFormat.bytes($0) } ?? "—")
            .monospacedDigit()
            .foregroundStyle(size == nil ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
    }
}

struct EntryContextMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    let ids: Set<PeekId>

    var body: some View {
        let entries = model.selectedEntries.filter { ids.contains($0.id) }
        if let first = entries.first {
            Button(entries.count == 1 ? "Copy URL" : "Copy \(entries.count) URLs") {
                copy(entries.map(\.request.uri.absoluteString).joined(separator: "\n"))
            }
            if entries.count == 1 {
                Button("Copy as cURL") { copy(MockExport.curl(first)) }
                Button("Copy as Text") { copy(MockExport.text(first)) }
                Button("Copy as Markdown") { copy(MockExport.markdown(first)) }
            }
            Divider()
            Button(entries.allSatisfy(\.isPinned) ? "Unpin" : "Pin") {
                model.togglePin(Set(entries.map(\.id)))
            }
            Divider()
            Button(entries.count == 1 ? "Open in New Window" : "Open \(min(entries.count, OpenEntryWindowsAction.limit)) in New Windows") {
                OpenEntryWindowsAction(model: model, openWindow: openWindow)(entries.map(\.id))
            }
            Button(entries.count == 1 ? "Export as HAR…" : "Export \(entries.count) as HAR…") {}
                .disabled(true)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview("Live") {
    let model = AppModel.preview(.live)
    ConsoleTableView(entries: model.filteredEntries)
        .environment(model)
        .frame(width: 1100, height: 600)
}

#Preview("Large — Dark") {
    let model = AppModel.preview(.large)
    ConsoleTableView(entries: model.filteredEntries)
        .environment(model)
        .frame(width: 1100, height: 600)
        .preferredColorScheme(.dark)
}
