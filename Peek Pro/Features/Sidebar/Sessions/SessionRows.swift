import SwiftUI

/// Larger than the system sidebar rows: the device list is what people scan first.
enum SidebarRowMetrics {
    static let iconFont = Font.system(size: 20)
    static let iconWidth: CGFloat = 28
    static let iconSpacing: CGFloat = 6
    static let verticalPadding: CGFloat = 4
    static let lineSpacing: CGFloat = 2
    /// Between the pause mark, the connection dot and the request count.
    static let accessorySpacing: CGFloat = 6
    /// Where the title starts, for text placed under a row.
    static let titleInset = iconWidth + iconSpacing
}

/// The system style pins the icon to the first line of the title; these rows have two, so it is centred.
struct SidebarRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: SidebarRowMetrics.iconSpacing) {
            SidebarRowIcon(icon: configuration.icon)
            configuration.title
        }
        .padding(.vertical, SidebarRowMetrics.verticalPadding)
    }
}

extension LabelStyle where Self == SidebarRowLabelStyle {
    static var sidebarRow: Self { .init() }
}

private struct SidebarRowIcon<Icon: View>: View {
    let icon: Icon
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        icon
            .font(SidebarRowMetrics.iconFont)
            .foregroundStyle(prominence == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
            .frame(width: SidebarRowMetrics.iconWidth)
    }
}

struct LiveSessionRow: View {
    let session: PeekLiveSession
    let count: Int
    let isPaused: Bool

    var body: some View {
        Label {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: SidebarRowMetrics.lineSpacing) {
                    Text(session.title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: SidebarRowMetrics.accessorySpacing) {
                    if isPaused {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .help("Recording paused")
                            .accessibilityLabel("Recording paused")
                    }
                    ConnectionDot(state: session.connection)
                    RequestCountBadge(count: count)
                }
            }
        } icon: {
            Image(systemName: session.info.platform.symbolName)
        }
        .labelStyle(.sidebarRow)
        .help("\(session.address) · Peek \(session.info.peekVersion) · connected \(PeekFormat.dateTime(session.connectedAt))")
    }

    private var subtitle: String {
        var parts = [session.info.systemTitle]
        // Without a name the address is already in the title.
        if session.info.name != nil { parts.append(session.address) }
        switch session.connection {
        case .connecting: parts.append("Connecting…")
        case .disconnected: parts.append("Disconnected")
        case .connected: break
        }
        return parts.joined(separator: " · ")
    }
}

/// The system badge is plain text in the sidebar; a plate keeps the number apart from the status marks.
struct RequestCountBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count, format: .number)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .accessibilityLabel("\(count) requests")
        }
    }
}

struct ConnectionDot: View {
    let state: PeekConnectionState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .help(title)
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
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: SidebarRowMetrics.lineSpacing) {
                    Text(file.name)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                RequestCountBadge(count: file.failure == nil ? count : 0)
            }
        } icon: {
            Image(systemName: "doc.text")
                .overlay(alignment: .bottomTrailing) {
                    if file.failure != nil {
                        StatusBadgeIcon(symbol: "xmark.circle.fill", color: Color(.statusFailure))
                    } else if file.hasWarnings {
                        StatusBadgeIcon(symbol: "exclamationmark.triangle.fill", color: .yellow)
                    }
                }
        }
        .labelStyle(.sidebarRow)
        .help(file.url.path(percentEncoded: false))
    }

    private var subtitle: String {
        if case .unsupportedFormat(let version) = file.failure {
            return "Can't open — format v\(version)"
        }
        return "\(PeekFormat.bytes(file.byteCount)) · \(PeekFormat.date(file.modifiedAt))"
    }
}

private struct StatusBadgeIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .background(Circle().fill(.background).padding(-1))
            .offset(x: 4, y: 3)
    }
}

struct RejectedConnectionRow: View {
    let connection: PeekRejectedConnection

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: SidebarRowMetrics.lineSpacing) {
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
        .labelStyle(.sidebarRow)
        .help("\(connection.reason.advice)\n\(connection.address), \(PeekFormat.time(connection.at))")
    }

    private var title: String {
        connection.name ?? [connection.platform?.title, connection.address].compactMap(\.self).joined(separator: " · ")
    }

    private var reason: String { connection.reason.title }
}

extension PeekRejectedConnection.Reason {
    var title: String {
        switch self {
        case .invalidToken: "Wrong token"
        case .wrongCode: "Wrong code"
        case .unsupportedProtocol(let version): "Protocol v\(version) is not supported"
        }
    }

    /// What the person at the device should do about it.
    var advice: String {
        switch self {
        case .invalidToken:
            "The app sent an old or mistyped token. Copy the current token into the app's PeekRemote setup and restart it."
        case .wrongCode:
            "The code was mistyped or had already changed. Enter the code shown now."
        case .unsupportedProtocol(let version):
            "The app speaks peek_remote protocol v\(version), newer than this Peek Pro understands. Update Peek Pro."
        }
    }
}
