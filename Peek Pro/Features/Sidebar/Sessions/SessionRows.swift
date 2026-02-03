import SwiftUI

struct AppHeader: View {
    static let iconSide: CGFloat = 22
    static let spacing: CGFloat = 8
    /// Devices sit under the app name, not under its icon.
    static let childIndent = iconSide + spacing

    let app: PeekApp

    var body: some View {
        HStack(spacing: Self.spacing) {
            Text(String(app.name.prefix(1)))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: Self.iconSide, height: Self.iconSide)
                .background(.tint, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 0) {
                Text(app.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(app.identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .textCase(nil)
        .padding(.vertical, 2)
        .help(app.version.map { "\(app.name) \($0)" } ?? app.name)
    }
}

struct LiveSessionRow: View {
    let session: PeekLiveSession
    let count: Int

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(session.info.device.name)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        } icon: {
            Image(systemName: session.info.device.symbolName)
                .overlay(alignment: .bottomTrailing) {
                    ConnectionDot(state: session.connection)
                        .offset(x: 4, y: 3)
                }
        }
        .padding(.leading, AppHeader.childIndent)
        .badge(count)
        .help("\(session.address) · connected \(PeekFormat.dateTime(session.connectedAt))")
    }

    private var subtitle: String {
        var parts = [session.info.device.systemTitle]
        if session.info.device.isSimulator { parts.append("Simulator") }
        switch session.connection {
        case .connecting: parts.append("Connecting…")
        case .disconnected: parts.append("Disconnected")
        case .connected: break
        }
        return parts.joined(separator: " · ")
    }
}

struct ConnectionDot: View {
    let state: PeekConnectionState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay { Circle().stroke(.background, lineWidth: 1.5) }
            .accessibilityLabel(title)
    }

    private var color: Color {
        switch state {
        case .connected: Color(.statusSuccess)
        case .connecting: .orange
        case .disconnected: Color(.statusNeutral)
        }
    }

    private var title: String {
        switch state {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .disconnected: "Disconnected"
        }
    }
}

struct SessionFileRow: View {
    let file: PeekSessionFile
    let count: Int

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .truncationMode(.middle)
                Text("\(PeekFormat.bytes(file.byteCount)) · \(PeekFormat.date(file.modifiedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        } icon: {
            Image(systemName: "doc.text")
        }
        .badge(count)
        .help(file.url.path(percentEncoded: false))
    }
}

struct RejectedConnectionRow: View {
    let connection: PeekRejectedConnection

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        } icon: {
            Image(systemName: "xmark.shield")
                .foregroundStyle(Color(.statusFailure))
        }
        .help("\(reason) — \(connection.address), \(PeekFormat.time(connection.at))")
    }

    private var title: String {
        [connection.deviceName, connection.appName].compactMap(\.self).joined(separator: " · ")
    }

    private var reason: String {
        switch connection.reason {
        case .invalidToken: "Wrong token"
        case .unsupportedProtocol(let version): "Protocol v\(version) is not supported"
        }
    }
}
