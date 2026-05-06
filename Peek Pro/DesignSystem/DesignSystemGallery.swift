import SwiftUI

/// Everything the design system offers, on real fixtures — for review in the canvas.
struct DesignSystemGallery: View {
    private let entries = ["f01", "f07", "f09", "f26", "f03", "f10", "f12", "f13", "f15", "f16", "f17"]
        .map { Fixtures.entry($0) }

    private let login = Fixtures.entry("f01")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Statuses")
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    ForEach(entries) { entry in
                        GridRow {
                            StatusIcon(entry: entry)
                            StatusLabel(entry: entry)
                            Text(entry.request.method)
                                .foregroundStyle(.secondary)
                            Text(entry.request.path)
                                .lineLimit(1)
                            Text(entry.duration.map { PeekFormat.duration($0) } ?? "—")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                        }
                    }
                }

                InfoTable(title: "Formatters", rows: [
                    InfoRow(title: "Bytes", value: [0, 367, 168_960, 7_025_459].map { PeekFormat.bytes($0) }.joined(separator: " · ")),
                    InfoRow(title: "Durations", value: [Duration.microseconds(420), .milliseconds(426.9), .seconds(4.465), .seconds(95)]
                        .map { PeekFormat.duration($0) }.joined(separator: " · ")),
                    InfoRow(title: "Time", value: PeekFormat.time(login.startedAt), isMonospaced: true),
                    InfoRow(title: "Date", value: PeekFormat.dateTime(login.startedAt)),
                ])

                InfoTable(title: "Information", rows: [
                    InfoRow(title: "Method", value: login.request.method),
                    InfoRow(title: "Host", value: login.request.host),
                    InfoRow(title: "Path", value: login.request.path),
                    InfoRow(title: "Authorization", value: "Bearer eyJhbGciOiJIUzI1NiIs…", isMonospaced: true),
                    InfoRow(title: "Source", value: login.source),
                ], collapsedCount: 3)

                SectionHeader("Timing")
                TimingPreview(timings: login.timings ?? PeekTimings())

                SectionHeader("Controls") {
                    CopyButton(text: login.request.uri.absoluteString, title: "Copy URL")
                }
                HStack(spacing: 8) {
                    CountBadge(count: 6)
                    CountBadge(count: 128)
                    CountBadge(count: 10_000)
                }
            }
            .padding(20)
        }
    }
}

private struct TimingSegment: Identifiable {
    let phase: PeekTimings.Phase
    let start: Double
    let length: Double
    let duration: Duration

    var id: PeekTimings.Phase { phase }
}

private struct TimingPreview: View {
    let timings: PeekTimings

    private var segments: [TimingSegment] {
        let known = timings.known
        let total = known.reduce(0) { $0 + $1.duration.timeInterval }
        guard total > 0 else { return [] }
        var elapsed = 0.0
        var result: [TimingSegment] = []
        for item in known {
            let length = item.duration.timeInterval
            result.append(TimingSegment(phase: item.phase, start: elapsed / total, length: length / total, duration: item.duration))
            elapsed += length
        }
        return result
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(segments) { segment in
                GridRow {
                    Text(segment.phase.title)
                        .foregroundStyle(.secondary)
                    TimingBar(start: segment.start, length: segment.length, color: segment.phase.color)
                    Text(PeekFormat.duration(segment.duration))
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                }
            }
        }
    }
}

#Preview("Light") {
    DesignSystemGallery()
        .frame(width: 560, height: 820)
}

#Preview("Dark") {
    DesignSystemGallery()
        .frame(width: 560, height: 820)
        .preferredColorScheme(.dark)
}
