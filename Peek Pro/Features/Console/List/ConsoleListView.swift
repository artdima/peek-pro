import SwiftUI

/// Pulse Pro's list mode: two-line rows grouped into sections.
struct ConsoleListView: View {
    @Environment(AppModel.self) private var model
    let entries: [PeekEntry]

    var body: some View {
        @Bindable var model = model
        let sections = model.listGrouping.sections(of: entries)

        ScrollViewReader { proxy in
            List(selection: $model.selectedEntryIDs) {
                ForEach(sections) { section in
                    if let title = section.title {
                        Section {
                            rows(section.entries)
                        } header: {
                            HStack(spacing: 6) {
                                Text(title)
                                Text(section.entries.count, format: .number)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        rows(section.entries)
                    }
                }
            }
            .listStyle(.inset)
            .contextMenu(forSelectionType: PeekId.self) { ids in
                EntryContextMenu(ids: ids)
            }
            .onChange(of: entries.last?.id) { _, last in
                guard model.isFollowing, let last else { return }
                withAnimation { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
    }

    private func rows(_ entries: [PeekEntry]) -> some View {
        ForEach(entries) { entry in
            ConsoleListRow(entry: entry)
                .tag(entry.id)
                .id(entry.id)
        }
    }
}

struct ConsoleListRow: View {
    let entry: PeekEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                StatusIcon(entry: entry)
                StatusLabel(entry: entry)
                Text(entry.request.method)
                    .foregroundStyle(.secondary)
                Text(metrics)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                Spacer(minLength: 8)
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.orange)
                        .help("Pinned")
                }
                Text(PeekFormat.time(entry.startedAt))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            Text(entry.request.uri.absoluteString)
                .foregroundStyle(entry.isError ? Color(.statusFailure) : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var metrics: String {
        let sent = PeekFormat.bytes(entry.requestSize ?? 0)
        let received = entry.responseSize.map { PeekFormat.bytes($0) } ?? "—"
        let duration = entry.duration.map { PeekFormat.duration($0) } ?? "…"
        return "↑ \(sent)   ↓ \(received)   ⏱ \(duration)"
    }
}

struct ListGroupingMenu: View {
    @Binding var grouping: ConsoleListGrouping

    var body: some View {
        Menu {
            Picker("Group By", selection: $grouping) {
                ForEach(ConsoleListGrouping.allCases) { grouping in
                    Text(grouping.title).tag(grouping)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Group By", systemImage: "rectangle.3.group")
        }
        .menuIndicator(.hidden)
        .help("Group the list by \(grouping.title.lowercased())")
    }
}

#Preview("By Status") {
    let model = AppModel.preview(.live)
    ConsoleListView(entries: model.filteredEntries)
        .environment(model)
        .frame(width: 900, height: 700)
}

#Preview("By Host — Dark") {
    let model = AppModel.preview(.live)
    model.listGrouping = .host
    return ConsoleListView(entries: model.filteredEntries)
        .environment(model)
        .frame(width: 900, height: 700)
        .preferredColorScheme(.dark)
}
