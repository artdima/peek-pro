import SwiftUI

struct InfoRow {
    let title: String
    let value: String
    var isMonospaced = false
    var isRedacted = false
}

/// Key on the left, value on the right, hairlines between — Pulse's "Information" block.
struct InfoTable: View {
    var title: String?
    let rows: [InfoRow]
    var collapsedCount: Int?

    @State private var isExpanded = false

    private var visibleRows: [InfoRow] {
        guard let collapsedCount, !isExpanded else { return rows }
        return Array(rows.prefix(collapsedCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                SectionHeader(title) {
                    if let collapsedCount, rows.count > collapsedCount {
                        Button(isExpanded ? "Show Less" : "Show More") {
                            isExpanded.toggle()
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            ForEach(Array(visibleRows.enumerated()), id: \.offset) { _, row in
                InfoRowView(row: row)
                Divider()
            }
        }
    }
}

struct InfoRowView: View {
    let row: InfoRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            if row.isRedacted {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .help("Redacted on the device")
            }
            Text(row.value)
                .font(row.isMonospaced ? .body.monospaced() : .body)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 5)
    }
}
