import Charts
import SwiftUI

struct InsightsPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let entries = model.selectedEntries
        if entries.isEmpty {
            ContentUnavailableView("No Data", systemImage: "chart.pie",
                                   description: Text("Insights appear once the session has requests."))
        } else {
            let insights = SessionInsights(entries)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StatTiles(insights: insights)
                    InsightSection("Duration") {
                        DurationHistogram(buckets: insights.buckets)
                    }
                    InsightSection("Status") {
                        StatusBreakdown(statuses: insights.statuses, total: insights.total)
                    }
                    InsightSection("Slowest") {
                        ForEach(insights.slowest) { entry in
                            SlowRequestRow(entry: entry) { model.reveal(entry.id) }
                        }
                    }
                    InsightSection("Hosts") {
                        HostBars(hosts: insights.hosts)
                    }
                    if !insights.redirected.isEmpty {
                        InsightSection("Redirects") {
                            ForEach(insights.redirected) { entry in
                                RedirectRow(entry: entry) { model.reveal(entry.id) }
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
    }
}

private struct InsightSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

private struct StatTiles: View {
    let insights: SessionInsights

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                StatTile(title: "Requests", value: insights.total.formatted())
                StatTile(title: "Errors", value: insights.errorRate.formatted(.percent.precision(.fractionLength(0))),
                         detail: "\(insights.errors) of \(insights.finished)")
            }
            GridRow {
                StatTile(title: "Median", value: insights.median.map { PeekFormat.duration($0) } ?? "—")
                StatTile(title: "95th pct", value: insights.p95.map { PeekFormat.duration($0) } ?? "—")
            }
            GridRow {
                StatTile(title: "Sent", value: PeekFormat.bytes(insights.sentBytes), symbol: "arrow.up")
                StatTile(title: "Received", value: PeekFormat.bytes(insights.receivedBytes), symbol: "arrow.down")
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    var detail: String?
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(title)
            } icon: {
                if let symbol { Image(systemName: symbol) }
            }
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// One series, one hue; the count shows on hover rather than on every bar.
private struct DurationHistogram: View {
    let buckets: [SessionInsights.Bucket]
    @State private var hovered: String?

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Requests", bucket.count),
                y: .value("Duration", bucket.title),
                height: .ratio(0.62)
            )
            .cornerRadius(4)
            .foregroundStyle(Color.accentColor.opacity(hovered == nil || hovered == bucket.title ? 1 : 0.35))
            .annotation(position: .trailing, spacing: 4) {
                if hovered == bucket.title {
                    Text("\(bucket.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }
        }
        .chartYSelection(value: $hovered)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel().font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel().font(.caption2)
            }
        }
        .frame(height: 150)
        .accessibilityLabel("Requests by duration")
    }
}

private struct StatusBreakdown: View {
    let statuses: [(slice: SessionInsights.StatusSlice, count: Int)]
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let gaps = CGFloat(max(statuses.count - 1, 0)) * 2
                HStack(spacing: 2) {
                    ForEach(statuses, id: \.slice) { item in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.slice.color)
                            .frame(width: max(3, (proxy.size.width - gaps) * CGFloat(item.count) / CGFloat(max(total, 1))))
                    }
                }
            }
            .frame(height: 10)

            ForEach(statuses, id: \.slice) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.slice.color)
                        .frame(width: 7, height: 7)
                    Text(item.slice.title)
                    Spacer()
                    Text(item.count, format: .number)
                        .monospacedDigit()
                    Text((Double(item.count) / Double(max(total, 1))).formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                .font(.callout)
            }
        }
    }
}

private struct SlowRequestRow: View {
    let entry: PeekEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.duration.map { PeekFormat.duration($0) } ?? "—")
                    .font(.callout.monospacedDigit().weight(.medium))
                    .frame(width: 58, alignment: .trailing)
                Text("\(entry.request.method) \(entry.request.path)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(entry.request.uri.absoluteString)
    }
}

private struct HostBars: View {
    let hosts: [SessionInsights.Host]

    var body: some View {
        let maximum = hosts.map(\.count).max() ?? 1
        VStack(alignment: .leading, spacing: 8) {
            ForEach(hosts) { host in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(host.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if host.errors > 0 {
                            Label("\(host.errors)", systemImage: "exclamationmark.circle.fill")
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(.secondary)
                                .help("\(host.errors) failed")
                        }
                        Text(host.count, format: .number)
                            .monospacedDigit()
                    }
                    .font(.callout)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(3, proxy.size.width * CGFloat(host.count) / CGFloat(maximum)))
                    }
                    .frame(height: 4)
                }
            }
        }
    }
}

private struct RedirectRow: View {
    let entry: PeekEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.request.method) \(entry.request.host)\(entry.request.path)")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(hops)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hops: String {
        let codes = (entry.response?.redirects ?? []).map { String($0.statusCode) }
        return (codes + [entry.statusCode.map(String.init) ?? "—"]).joined(separator: " → ")
    }
}

extension SessionInsights.StatusSlice {
    var color: Color {
        switch self {
        case .success: Color(.statusSuccess)
        case .redirect: Color(.statusRedirect)
        case .clientError: Color(.statusClientError)
        case .serverError: Color(.statusServerError)
        case .failed: Color(.statusFailure)
        case .pending: Color(.statusNeutral)
        }
    }
}

#Preview("Live") {
    InsightsPanel()
        .environment(AppModel.preview(.live))
        .frame(width: 280, height: 1000)
}

#Preview("Large — Dark") {
    InsightsPanel()
        .environment(AppModel.preview(.large))
        .frame(width: 280, height: 1000)
        .preferredColorScheme(.dark)
}
