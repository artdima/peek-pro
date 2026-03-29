import AppKit
import SwiftUI

struct KeyValuePair: Identifiable, Hashable {
    let id: Int
    let name: String
    let value: String

    /// Peek masks secrets on the device with this token.
    var isRedacted: Bool { value.contains("*****") }

    static func list(_ pairs: [(name: String, value: String)]) -> [KeyValuePair] {
        pairs.enumerated().map { KeyValuePair(id: $0.offset, name: $0.element.name, value: $0.element.value) }
    }
}

/// Monospaced name / value rows with a section title, a count and Copy All.
struct KeyValueSection: View {
    let title: String
    let pairs: [KeyValuePair]
    var emptyText = "None"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(pairs.count, format: .number)
                    .foregroundStyle(.tertiary)
                Spacer()
                if !pairs.isEmpty {
                    CopyButton(text: pairs.map { "\($0.name): \($0.value)" }.joined(separator: "\n"), title: "Copy All")
                }
            }
            .padding(.bottom, 6)
            if pairs.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(pairs.enumerated()), id: \.element.id) { index, pair in
                    KeyValueRowView(pair: pair)
                        .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04),
                                    in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

struct KeyValueRowView: View {
    let pair: KeyValuePair
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(pair.name)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 200, alignment: .leading)
                .help(pair.name)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if pair.isRedacted {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help("Redacted on the device")
                }
                Text(pair.value)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            CopyButton(text: pair.value, title: "Copy Value")
                .opacity(isHovered ? 1 : 0)
        }
        .font(.callout.monospaced())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy Value") { copy(pair.value) }
            Button("Copy Name") { copy(pair.name) }
            Button("Copy “\(pair.name): …”") { copy("\(pair.name): \(pair.value)") }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// Wraps its children onto new lines, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
