import SwiftUI

/// Notices about the session itself, above the list.
struct ConsoleBanners: View {
    @Environment(AppModel.self) private var model
    @State private var dismissedDrops: Set<PeekSessionID> = []

    var body: some View {
        if let session = model.selectedLiveSession {
            VStack(spacing: 0) {
                if model.store.isPaused(session.id) {
                    ConsoleBanner(symbol: "pause.circle.fill", tint: .orange,
                                  title: "Recording is paused",
                                  detail: "New requests from the device are not shown.") {
                        Button("Resume") { model.store.togglePaused(session.id) }
                    }
                }
                if session.connection == .disconnected {
                    ConsoleBanner(symbol: "bolt.horizontal.circle.fill", tint: Color(.statusNeutral),
                                  title: "Device disconnected",
                                  detail: disconnectedDetail(session)) {
                        EmptyView()
                    }
                }
                if session.droppedCount > 0, !dismissedDrops.contains(session.id) {
                    ConsoleBanner(symbol: "exclamationmark.triangle.fill", tint: .yellow,
                                  title: "The device dropped \(session.droppedCount) entries",
                                  detail: "Its send queue overflowed; those requests never reached Peek Pro.") {
                        Button("Dismiss") { dismissedDrops.insert(session.id) }
                    }
                }
            }
        }
    }

    private func disconnectedDetail(_ session: PeekLiveSession) -> String {
        let time = session.disconnectedAt.map { " at \(PeekFormat.time($0))" } ?? ""
        return "Lost the connection\(time). Showing the last received data."
    }
}

private struct ConsoleBanner<Actions: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .fontWeight(.semibold)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                actions
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(tint.opacity(0.1))
            Divider()
        }
    }
}

/// Floats over the list while Follow is off and new requests keep coming.
struct NewRequestsPill: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let count = model.unseenCount
        if count > 0 {
            Button {
                model.showLatest()
            } label: {
                Label("\(count) new \(count == 1 ? "request" : "requests")", systemImage: "arrow.down")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .padding(.bottom, 14)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview("Paused") {
    ConsoleBanners()
        .environment(AppModel.preview(.paused))
        .frame(width: 800)
}

#Preview("Disconnected — Dark") {
    ConsoleBanners()
        .environment(AppModel.preview(.disconnected))
        .frame(width: 800)
        .preferredColorScheme(.dark)
}

#Preview("Dropped") {
    let model = AppModel.preview(.live)
    model.selectedSessionID = FixtureSessions.pixelSession.id
    return ConsoleBanners()
        .environment(model)
        .frame(width: 800)
}
