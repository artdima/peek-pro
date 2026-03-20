import SwiftUI

/// Pulse's three columns — the outcome, where the time went, what was sent — folding to two or one when narrow.
struct SummaryTab: View {
    let entry: PeekEntry
    let showTab: (DetailTab) -> Void

    var body: some View {
        GeometryReader { proxy in
            let columns = proxy.size.width >= 1000 ? 3 : (proxy.size.width >= 620 ? 2 : 1)
            ScrollView {
                switch columns {
                case 3:
                    HStack(alignment: .top, spacing: 0) {
                        overview
                        Divider()
                        timing
                        Divider()
                        request
                    }
                case 2:
                    HStack(alignment: .top, spacing: 0) {
                        overview
                        Divider()
                        VStack(spacing: 0) {
                            timing
                            Divider()
                            request
                        }
                    }
                default:
                    VStack(spacing: 0) {
                        overview
                        Divider()
                        timing
                        Divider()
                        request
                    }
                }
            }
        }
    }

    private var overview: some View {
        SummaryColumn {
            OverviewColumn(entry: entry, showTab: showTab)
        }
    }

    private var timing: some View {
        SummaryColumn {
            HStack {
                Text("Timing")
                    .font(.headline)
                Spacer()
                if let duration = entry.duration {
                    Text(PeekFormat.duration(duration))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            TimingWaterfall(entry: entry)
        }
    }

    private var request: some View {
        SummaryColumn {
            RequestColumn(entry: entry)
        }
    }
}

private struct SummaryColumn<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct OverviewColumn: View {
    let entry: PeekEntry
    let showTab: (DetailTab) -> Void

    var body: some View {
        HStack(spacing: 8) {
            StatusIcon(entry: entry)
            StatusLabel(entry: entry)
                .font(.title3)
            Spacer()
            if let duration = entry.duration {
                Text(PeekFormat.duration(duration))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }

        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(entry.request.uri.absoluteString)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            CopyButton(text: entry.request.uri.absoluteString, title: "Copy URL")
        }

        if let failure = entry.failure {
            FailureNotice(failure: failure) { showTab(.error) }
        }

        HStack(alignment: .top) {
            TransferBlock(title: "Sent", symbol: "arrow.up.circle",
                          headers: entry.request.headers.byteCount, bodySize: entry.request.body.size)
            Spacer(minLength: 12)
            TransferBlock(title: "Received", symbol: "arrow.down.circle",
                          headers: entry.response?.headers.byteCount, bodySize: entry.response?.contentLength)
        }
        .padding(.vertical, 4)

        InfoTable(title: "Information", rows: informationRows, collapsedCount: 5)

        if let redirects = entry.response?.redirects, !redirects.isEmpty {
            InfoTable(title: "Redirects", rows: redirects.map { redirect in
                InfoRow(title: "\(redirect.statusCode) \(redirect.method)", value: redirect.location.absoluteString)
            })
        }
    }

    private var informationRows: [InfoRow] {
        let started = "\(PeekFormat.date(entry.startedAt)) at \(PeekFormat.time(entry.startedAt))"
        var rows = [
            InfoRow(title: "Method", value: entry.request.method),
            InfoRow(title: "Started", value: started),
            InfoRow(title: "Duration", value: entry.duration.map { PeekFormat.duration($0) } ?? "In progress"),
            InfoRow(title: "State", value: entry.state.title),
            InfoRow(title: "Source", value: entry.source),
            InfoRow(title: "Pinned", value: entry.isPinned ? "Yes" : "No"),
        ]
        if let mediaType = entry.response?.mediaType ?? entry.request.mediaType {
            rows.insert(InfoRow(title: "Content Type", value: mediaType.mimeType), at: 3)
        }
        return rows
    }
}

private struct FailureNotice: View {
    let failure: PeekFailure
    let showError: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: failure.kind == .cancelled ? "xmark.circle.fill" : "exclamationmark.octagon.fill")
                .font(.title3)
                .foregroundStyle(failure.kind == .cancelled ? Color(.statusNeutral) : Color(.statusFailure))
            VStack(alignment: .leading, spacing: 2) {
                Text(failure.kind.title)
                    .fontWeight(.semibold)
                Text(failure.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 8)
            Button("Show Error", action: showError)
        }
        .padding(10)
        .background(Color(.statusFailure).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TransferBlock: View {
    let title: String
    let symbol: String
    let headers: Int?
    let bodySize: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(total)
                    .font(.title3.weight(.semibold).monospacedDigit())
                Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 1) {
                    GridRow {
                        Text("Headers:")
                            .foregroundStyle(.secondary)
                        Text(headers.map { PeekFormat.bytes($0) } ?? "—")
                    }
                    GridRow {
                        Text("Body:")
                            .foregroundStyle(.secondary)
                        Text(bodySize.map { PeekFormat.bytes($0) } ?? "—")
                    }
                }
                .font(.caption.monospacedDigit())
            }
        }
    }

    private var total: String {
        guard headers != nil || bodySize != nil else { return "—" }
        return PeekFormat.bytes((headers ?? 0) + (bodySize ?? 0))
    }
}

private struct RequestColumn: View {
    let entry: PeekEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.request.method)
                .font(.headline)
            Text(entry.request.uri.absoluteString)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }

        InfoTable(title: "Information", rows: [
            InfoRow(title: "Scheme", value: entry.request.uri.scheme ?? "—"),
            InfoRow(title: "Host", value: entry.request.host),
            InfoRow(title: "Path", value: entry.request.path.isEmpty ? "/" : entry.request.path),
            InfoRow(title: "Query", value: entry.request.query ?? "—"),
        ])

        let headers = entry.request.headers.entries
        if !headers.isEmpty {
            InfoTable(title: "Request Headers", rows: headers.map { header in
                InfoRow(title: header.name, value: header.value, isRedacted: header.value.contains("*****"))
            }, collapsedCount: 6)
        }
    }
}

#Preview("Login — 3 columns") {
    SummaryTab(entry: Fixtures.entry("f01")) { _ in }
        .frame(width: 1240, height: 560)
}

#Preview("Timeout — 2 columns, Dark") {
    SummaryTab(entry: Fixtures.entry("f12")) { _ in }
        .frame(width: 820, height: 700)
        .preferredColorScheme(.dark)
}

#Preview("Redirect — 1 column") {
    SummaryTab(entry: Fixtures.entry("f09")) { _ in }
        .frame(width: 520, height: 900)
}

#Preview("Pending") {
    SummaryTab(entry: Fixtures.entry("f17")) { _ in }
        .frame(width: 1240, height: 520)
}
