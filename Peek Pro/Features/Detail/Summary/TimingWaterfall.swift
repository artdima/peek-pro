import SwiftUI

/// Phases laid out on one timeline, grouped the way Pulse groups them.
struct TimingWaterfall: View {
    let entry: PeekEntry

    private static let groups: [(title: String, phases: [PeekTimings.Phase])] = [
        ("Scheduling", [.blocked]),
        ("Connection", [.dns, .connect, .ssl]),
        ("Response", [.send, .wait, .receive]),
    ]

    var body: some View {
        if entry.state == .pending {
            PendingTiming(startedAt: entry.startedAt)
        } else if let timings = entry.timings, !timings.known.isEmpty {
            phases(timings)
        } else {
            totalOnly
        }
    }

    private func phases(_ timings: PeekTimings) -> some View {
        let segments = Self.segments(timings, total: entry.duration)
        return Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
            ForEach(Self.groups, id: \.title) { group in
                let rows = group.phases.compactMap { segments[$0] }
                if !rows.isEmpty {
                    GridRow {
                        Text(group.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 6)
                            .gridCellColumns(3)
                    }
                    ForEach(rows, id: \.phase) { row in
                        GridRow {
                            Text(row.phase.title)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            TimingBar(start: row.start, length: row.length, color: row.phase.color)
                                .frame(minWidth: 80)
                            Text(PeekFormat.duration(row.duration))
                                .font(.callout.monospacedDigit())
                                .gridColumnAlignment(.trailing)
                        }
                    }
                }
            }
        }
    }

    private var totalOnly: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Total")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TimingBar(start: 0, length: 1, color: entry.tint)
                Text(entry.duration.map { PeekFormat.duration($0) } ?? "—")
                    .font(.callout.monospacedDigit())
            }
            Text("This source doesn't report timing phases — only the total, measured by Peek.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private struct Segment {
        let phase: PeekTimings.Phase
        let start: Double
        let length: Double
        let duration: Duration
    }

    private static func segments(_ timings: PeekTimings, total: Duration?) -> [PeekTimings.Phase: Segment] {
        let known = timings.known
        let sum = known.reduce(0) { $0 + $1.duration.timeInterval }
        let span = max(sum, total?.timeInterval ?? 0)
        guard span > 0 else { return [:] }
        var elapsed = 0.0
        var result: [PeekTimings.Phase: Segment] = [:]
        for item in known {
            let length = item.duration.timeInterval
            result[item.phase] = Segment(phase: item.phase, start: elapsed / span, length: length / span, duration: item.duration)
            elapsed += length
        }
        return result
    }
}

private struct PendingTiming: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("In progress")
                    Spacer()
                    Text(PeekFormat.duration(.seconds(elapsed)))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
    }
}
