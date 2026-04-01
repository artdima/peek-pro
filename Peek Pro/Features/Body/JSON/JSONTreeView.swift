import AppKit
import SwiftUI

struct JSONTreeView: View {
    let text: String

    private enum LoadState {
        case loading
        case parsed(JSONValue)
        case failed
    }

    @State private var state = LoadState.loading
    @State private var expanded: Set<String> = []

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed:
                ContentUnavailableView {
                    Label("Not Valid JSON", systemImage: "curlybraces")
                } description: {
                    Text("The body can't be parsed — it may be cut short. Switch to Raw to read it as text.")
                }
            case .parsed(let root):
                tree(root)
            }
        }
        .task(id: text) {
            state = .loading
            let source = text
            let root = await Task.detached(priority: .userInitiated) {
                JSONParser.parse(source)
            }.value
            guard !Task.isCancelled else { return }
            if let root {
                expanded = JSONTree.initialExpansion(root)
                state = .parsed(root)
            } else {
                state = .failed
            }
        }
    }

    private func tree(_ root: JSONValue) -> some View {
        let rows = JSONTree.rows(root, expanded: expanded)
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button("Expand All") { expanded = JSONTree.allContainerPaths(root) }
                Button("Collapse All") { expanded = [JSONTree.rootID] }
                Spacer()
                Text("\(rows.count) rows")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .buttonStyle(.link)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            Divider()
            List(rows) { row in
                JSONTreeRowView(row: row, isExpanded: expanded.contains(row.id)) {
                    toggle(row.id)
                }
                .contextMenu {
                    if row.value.isContainer {
                        Button(expanded.contains(row.id) ? "Collapse" : "Expand") { toggle(row.id) }
                        Divider()
                    }
                    Button("Copy Value") { copy(JSONTree.format(row.value)) }
                    if row.id != JSONTree.rootID {
                        Button("Copy Path") { copy(JSONTree.displayPath(row.id)) }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func toggle(_ id: String) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct JSONTreeRowView: View {
    let row: JSONTreeRow
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Color.clear
                .frame(width: CGFloat(row.depth) * 14, height: 1)
            if row.value.isContainer {
                Button(action: toggle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Color.clear
                    .frame(width: 12, height: 1)
            }
            if let key = row.key {
                Text(key)
                    .foregroundStyle(row.isIndex ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
                Text(":")
                    .foregroundStyle(.tertiary)
            }
            valueText
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .font(.system(.callout, design: .monospaced))
        .lineLimit(1)
        .help(JSONTree.displayPath(row.id))
    }

    @ViewBuilder
    private var valueText: some View {
        switch row.value {
        case .object(let members):
            Text("{ \(members.count) }")
                .foregroundStyle(.secondary)
        case .array(let items):
            Text("[ \(items.count) ]")
                .foregroundStyle(.secondary)
        case .string(let text):
            Text("\"\(text)\"")
                .foregroundStyle(Color(.codeString))
        case .number(let number):
            Text(number)
                .foregroundStyle(Color(.codeNumber))
        case .bool(let flag):
            Text(flag ? "true" : "false")
                .foregroundStyle(Color(.codeKeyword))
        case .null:
            Text("null")
                .foregroundStyle(Color(.codeKeyword))
        }
    }
}

#Preview("Profile") {
    JSONTreeView(text: FixtureBodies.profile)
        .frame(width: 600, height: 500)
}

#Preview("Catalog — Dark") {
    JSONTreeView(text: FixtureBodies.catalog)
        .frame(width: 600, height: 500)
        .preferredColorScheme(.dark)
}

#Preview("Truncated") {
    JSONTreeView(text: FixtureBodies.truncatedFeed)
        .frame(width: 600, height: 300)
}
