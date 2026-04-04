import SwiftUI

struct UnavailableBodyView: View {
    let reason: PeekBodyUnavailableReason
    let contentType: PeekMediaType?
    let size: Int?

    var body: some View {
        ContentUnavailableView {
            Label("Body Not Available", systemImage: symbol)
        } description: {
            VStack(spacing: 6) {
                Text(reason.title)
                Text(explanation)
                    .font(.callout)
                if !facts.isEmpty {
                    Text(facts)
                        .font(.callout.monospaced())
                }
            }
        }
    }

    private var symbol: String {
        switch reason {
        case .streamed: "water.waves"
        case .tooLarge: "externaldrive.badge.exclamationmark"
        case .notCaptured: "eye.slash"
        case .unreadable: "doc.badge.ellipsis"
        }
    }

    private var explanation: String {
        switch reason {
        case .streamed: "The app read it as a stream, so there was nothing for Peek to keep."
        case .tooLarge: "It was over the size Peek keeps; only its size and type were recorded."
        case .notCaptured: "The adapter that recorded this call doesn't capture bodies."
        case .unreadable: "Peek couldn't read it when the call happened."
        }
    }

    private var facts: String {
        [contentType?.mimeType, size.map { PeekFormat.bytes($0) }].compactMap(\.self).joined(separator: " · ")
    }
}

/// A body that stayed on the device; loaded only when asked, so live traffic stays light.
struct RemoteBodyView: View {
    @Environment(AppModel.self) private var model
    let size: Int
    let contentType: PeekMediaType?
    let loadKey: PeekBodyLoadKey?

    var body: some View {
        let state = loadKey.flatMap { model.store.bodyLoads[$0] }
        switch (model.remoteBodyAvailability, state) {
        case (_, .loading?):
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading \(PeekFormat.bytes(size)) from \(model.selectedDeviceName)…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case (.notInFile, _):
            ContentUnavailableView {
                Label("Body Not Saved", systemImage: "doc.badge.ellipsis")
            } description: {
                Text("It stayed on the device when this session was saved. \(facts)")
            }
        case (.offline, _):
            ContentUnavailableView {
                Label("Device Disconnected", systemImage: "bolt.horizontal.circle")
            } description: {
                Text("The body stayed on \(model.selectedDeviceName). Reconnect the device to load it. \(facts)")
            }
        case (.available, .failed(let message)?):
            ContentUnavailableView {
                Label("Couldn't Load the Body", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again", action: load)
            }
        case (.available, nil):
            ContentUnavailableView {
                Label("Body Is on the Device", systemImage: "iphone.and.arrow.forward")
            } description: {
                Text("\(facts)\nPeek Pro loads bodies when you open them, to keep live traffic light.")
            } actions: {
                Button("Load Body", action: load)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var facts: String {
        [PeekFormat.bytes(size), contentType?.mimeType].compactMap(\.self).joined(separator: " · ")
    }

    private func load() {
        guard let loadKey else { return }
        model.loadBody(loadKey)
    }
}

struct TruncationBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scissors")
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
    }
}

#Preview("Too Large") {
    UnavailableBodyView(reason: .tooLarge, contentType: PeekMediaType("application", "zip"), size: 48_211_730)
        .frame(width: 700, height: 320)
}

#Preview("Remote") {
    RemoteBodyView(size: 18_432, contentType: .json, loadKey: PeekBodyLoadKey(entryID: PeekId("f24"), side: .response))
        .environment(AppModel.preview(.live))
        .frame(width: 700, height: 320)
}

#Preview("Remote, Offline — Dark") {
    RemoteBodyView(size: 18_432, contentType: .json, loadKey: PeekBodyLoadKey(entryID: PeekId("f24"), side: .response))
        .environment(AppModel.preview(.disconnected))
        .frame(width: 700, height: 320)
        .preferredColorScheme(.dark)
}
