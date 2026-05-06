import AppKit
import SwiftUI

/// Formatted JSON with line numbers and folding — the way Pulse shows a response.
struct JSONTreeView: View {
    let text: String

    private enum LoadState {
        case loading
        case parsed(JSONValue)
        case failed
    }

    @AppStorage(SettingsKey.bodyFontSize) private var fontSize = 12.0
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
                document(root)
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

    private func document(_ root: JSONValue) -> some View {
        let lines = JSONTree.lines(root, expanded: expanded)
        let gutter = CGFloat(max(2, String(lines.count).count)) * fontSize * 0.62 + 8
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button("Expand All") { expanded = JSONTree.allContainerPaths(root) }
                Button("Collapse All") { expanded = [JSONTree.rootID] }
                Spacer()
                Text("\(lines.count) lines")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .buttonStyle(.link)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        JSONLineView(line: line, number: index + 1, gutter: gutter, fontSize: fontSize) {
                            toggle(line.path)
                        }
                        .contextMenu { menu(for: line, root: root) }
                    }
                }
                .padding(.vertical, 8)
                .padding(.trailing, 12)
                .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private func menu(for line: JSONLine, root: JSONValue) -> some View {
        if line.isContainerLine {
            Button(expanded.contains(line.path) ? "Collapse" : "Expand") { toggle(line.path) }
            Divider()
        }
        Button("Copy Value") {
            if let value = JSONTree.value(at: line.path, in: root) {
                copy(JSONTree.format(value))
            }
        }
        if line.path != JSONTree.rootID {
            Button("Copy Path") { copy(JSONTree.displayPath(line.path)) }
        }
    }

    private func toggle(_ path: String) {
        if expanded.contains(path) {
            expanded.remove(path)
        } else {
            expanded.insert(path)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct JSONLineView: View {
    let line: JSONLine
    let number: Int
    let gutter: CGFloat
    let fontSize: Double
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(number)")
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: gutter, alignment: .trailing)
            foldButton
                .frame(width: fontSize * 1.4)
            Text(content)
                .padding(.leading, CGFloat(line.depth) * indent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: fontSize, design: .monospaced))
        .help(JSONTree.displayPath(line.path))
    }

    /// Two characters of the monospaced font, like a two-space indent.
    private var indent: CGFloat { fontSize * 1.2 }

    @ViewBuilder
    private var foldButton: some View {
        if line.isFoldable {
            let isOpen = line.isExpanded
            Button(action: toggle) {
                Image(systemName: "chevron.right")
                    .font(.system(size: fontSize * 0.7, weight: .semibold))
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .foregroundStyle(.secondary)
                    .frame(width: fontSize * 1.4, height: fontSize * 1.2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isOpen ? "Collapse" : "Expand")
        } else {
            Color.clear
                .frame(height: 1)
        }
    }

    private var content: AttributedString {
        var text = AttributedString()
        if let key = line.key {
            text += piece(JSONTree.quoted(key), Color.primary)
            text += piece(": ", Color.secondary)
        }
        switch line.kind {
        case .leaf(let value):
            text += valueText(value)
        case .open(let bracket):
            text += piece(String(bracket), Color.secondary)
        case .close(let bracket):
            text += piece(String(bracket), Color.secondary)
        case .folded(let open, let close, let count):
            text += piece("\(open) … \(close)", Color.secondary)
            text += piece("  \(count) \(count == 1 ? "item" : "items")", Color(nsColor: .tertiaryLabelColor))
        }
        if line.hasComma {
            text += piece(",", Color.secondary)
        }
        return text
    }

    private func valueText(_ value: JSONValue) -> AttributedString {
        switch value {
        case .string(let string): piece(JSONTree.quoted(string), Color(.codeString))
        case .number(let number): piece(number, Color(.codeNumber))
        case .bool(let flag): piece(flag ? "true" : "false", Color(.codeKeyword))
        case .null: piece("null", Color(.codeKeyword))
        case .object: piece("{}", Color.secondary)
        case .array: piece("[]", Color.secondary)
        }
    }

    private func piece(_ string: String, _ color: Color) -> AttributedString {
        var text = AttributedString(string)
        text.foregroundColor = color
        return text
    }
}

#Preview("Login") {
    JSONTreeView(text: FixtureBodies.loginResponse)
        .frame(width: 700, height: 500)
}

#Preview("Catalog — Dark") {
    JSONTreeView(text: FixtureBodies.catalog)
        .frame(width: 700, height: 500)
        .preferredColorScheme(.dark)
}

#Preview("Truncated") {
    JSONTreeView(text: FixtureBodies.truncatedFeed)
        .frame(width: 600, height: 300)
}
