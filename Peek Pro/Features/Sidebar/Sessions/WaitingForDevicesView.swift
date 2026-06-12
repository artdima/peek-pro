import SwiftUI

struct WaitingForDevicesView: View {
    @Environment(AppModel.self) private var model

    private var server: PeekServerState { model.store.server }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if !model.store.rejected.isEmpty {
                    rejected
                }
                if server.status == .portInUse {
                    portInUse
                } else {
                    connectionDetails
                    snippet
                    hints
                }
                actions
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative, isActive: server.status == .listening)
            Text("Waiting for Devices")
                .font(.headline)
            Text("Start PeekRemote in your app and its requests show up here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var rejected: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couldn't Connect")
                .font(.subheadline.weight(.semibold))
            ForEach(model.store.rejected) { connection in
                VStack(alignment: .leading, spacing: 4) {
                    RejectedConnectionRow(connection: connection)
                        .font(.callout)
                    Text(connection.reason.advice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, SidebarRowMetrics.titleInset)
                }
            }
        }
    }

    private var portInUse: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Port \(String(server.port)) is in use", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Another app is listening on this port. Quit it or choose another port, then update the endpoint in your app.")
                .font(.callout)
                .foregroundStyle(.secondary)
            SettingsLink {
                Text("Change Port…")
            }
            .padding(.top, 4)
        }
    }

    private var connectionDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Address")
                .font(.subheadline.weight(.semibold))
            ForEach(server.addresses, id: \.self) { address in
                CopyableValue(value: "\(address):\(server.port)")
            }
            Text("Token")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)
            HStack(spacing: 4) {
                CopyableValue(value: server.token)
                Button {
                    model.store.regenerateToken()
                } label: {
                    Label("New Token", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("New token — devices with the old one are refused")
            }
        }
    }

    private var snippetText: String {
        """
        PeekRemote(
          peek,
          endpoint: PeekRemoteEndpoint('\(server.addresses.first ?? "localhost")', \(server.port)),
          token: '\(server.token)',
          name: 'My App', // optional: how Peek Pro lists this app
        ).start();
        """
    }

    private var snippet: some View {
        Text(snippetText)
            .font(.caption.monospaced())
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                CopyButton(text: snippetText, title: "Copy Code")
                    .padding(6)
            }
    }

    private var adbCommand: String {
        "adb reverse tcp:\(server.port) tcp:\(server.port)"
    }

    private var hints: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text("Android over USB: \(Text(adbCommand).monospaced())")
            } icon: {
                Image(systemName: "cable.connector")
            }
            Label("iOS Simulator: use `localhost`", systemImage: "iphone")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                model.showOpenPanel()
            } label: {
                Text("Open File…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button {
                model.openDemoFiles()
            } label: {
                Text("Open Demo Session")
                    .frame(maxWidth: .infinity)
            }
        }
        .controlSize(.large)
    }
}

private struct CopyableValue: View {
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            CopyButton(text: value)
        }
    }
}

struct ServerStatusFooter: View {
    let server: PeekServerState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Circle()
                    .fill(server.status == .listening ? Color(.statusSuccess) : .orange)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if server.status == .portInUse {
                    SettingsLink {
                        Text("Change…")
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
        .help(server.bonjourName ?? "")
    }

    private var title: String {
        switch server.status {
        case .listening: "Listening on port \(server.port)"
        case .portInUse: "Port \(server.port) is in use"
        }
    }
}

#Preview("Waiting") {
    WaitingForDevicesView()
        .environment(AppModel.preview(.waiting))
        .frame(width: 290, height: 700)
}

#Preview("Port in Use — Dark") {
    WaitingForDevicesView()
        .environment(AppModel.preview(.portInUse))
        .frame(width: 290, height: 520)
        .preferredColorScheme(.dark)
}

#Preview("Rejected") {
    WaitingForDevicesView()
        .environment(AppModel.preview(.rejected))
        .frame(width: 290, height: 760)
}
