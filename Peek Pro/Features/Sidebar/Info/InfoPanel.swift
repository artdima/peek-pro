import AppKit
import SwiftUI

struct InfoPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let id = model.selectedSessionID, let info = model.store.info(for: id) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    SessionHeader(info: info)
                    if let session = model.store.session(id) {
                        InfoTable(title: "Connection", rows: connectionRows(session))
                        if session.connection != .disconnected {
                            Button("Disconnect") { model.store.disconnect(id) }
                                .padding(.top, 8)
                        }
                    }
                    if let file = model.store.file(id) {
                        InfoTable(title: "File", rows: fileRows(file))
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([file.url])
                        }
                        .padding(.top, 8)
                    }
                    InfoTable(title: "Client", rows: clientRows(info))
                    InfoTable(title: "Requests", rows: requestRows(model.store.entries(in: id)))
                }
                .padding(14)
            }
        } else {
            ContentUnavailableView("No Session Selected", systemImage: "info.circle")
        }
    }

    private func connectionRows(_ session: PeekLiveSession) -> [InfoRow] {
        var rows = [
            InfoRow(title: "Status", value: status(of: session)),
            InfoRow(title: "Address", value: session.address, isMonospaced: true),
            InfoRow(title: "Connected", value: PeekFormat.dateTime(session.connectedAt)),
        ]
        if let disconnectedAt = session.disconnectedAt {
            rows.append(InfoRow(title: "Disconnected", value: PeekFormat.dateTime(disconnectedAt)))
        }
        if session.droppedCount > 0 {
            rows.append(InfoRow(title: "Dropped", value: "\(session.droppedCount) entries"))
        }
        return rows
    }

    private func status(of session: PeekLiveSession) -> String {
        switch session.connection {
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        }
    }

    private func fileRows(_ file: PeekSessionFile) -> [InfoRow] {
        var rows = [
            InfoRow(title: "Name", value: file.name),
            InfoRow(title: "Folder", value: file.url.deletingLastPathComponent().path(percentEncoded: false), isMonospaced: true),
            InfoRow(title: "Size", value: PeekFormat.bytes(file.byteCount)),
            InfoRow(title: "Modified", value: PeekFormat.dateTime(file.modifiedAt)),
            InfoRow(title: "Format", value: formatText(file)),
        ]
        if case .unsupportedFormat = file.failure {
            rows.append(InfoRow(title: "Status", value: "Can't be opened"))
        }
        if file.skippedLines > 0 {
            rows.append(InfoRow(title: "Skipped", value: "\(file.skippedLines) unreadable lines"))
        }
        return rows
    }

    private func formatText(_ file: PeekSessionFile) -> String {
        if file.failure != nil { return "Version \(file.formatVersion) (no longer supported)" }
        if file.isNewerFormat { return "Version \(file.formatVersion) (newer than this app)" }
        return "Version \(file.formatVersion)"
    }

    private func clientRows(_ info: PeekSessionInfo) -> [InfoRow] {
        [
            InfoRow(title: "Name", value: info.name ?? "Not set"),
            InfoRow(title: "System", value: info.systemTitle),
            InfoRow(title: "Peek", value: info.peekVersion),
            InfoRow(title: "Started", value: PeekFormat.dateTime(info.startedAt)),
        ]
    }

    private func requestRows(_ entries: [PeekEntry]) -> [InfoRow] {
        let sources = Set(entries.map(\.source)).sorted().joined(separator: ", ")
        let bytes = entries.reduce(0) { $0 + ($1.totalSize ?? 0) }
        var rows = [
            InfoRow(title: "Count", value: entries.count.formatted()),
            InfoRow(title: "Pinned", value: entries.filter(\.isPinned).count.formatted()),
            InfoRow(title: "Bodies", value: PeekFormat.bytes(bytes)),
            InfoRow(title: "Adapters", value: sources.isEmpty ? "—" : sources),
        ]
        let starts = entries.map(\.startedAt)
        if let first = starts.min(), let last = starts.max() {
            rows.append(InfoRow(title: "First", value: PeekFormat.time(first), isMonospaced: true))
            rows.append(InfoRow(title: "Last", value: PeekFormat.time(last), isMonospaced: true))
        }
        return rows
    }
}

private struct SessionHeader: View {
    let info: PeekSessionInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: info.platform.symbolName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name ?? info.platform.title)
                    .font(.headline)
                Text(info.systemTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .padding(.bottom, 4)
    }
}

#Preview("Live") {
    InfoPanel()
        .environment(AppModel.preview(.live))
        .frame(width: 280, height: 900)
}

#Preview("Pixel — Dark") {
    let model = AppModel.preview(.live)
    model.selectedSessionID = FixtureSessions.pixelSession.id
    return InfoPanel()
        .environment(model)
        .frame(width: 280, height: 900)
        .preferredColorScheme(.dark)
}

#Preview("File") {
    let model = AppModel.preview(.file)
    model.selectedSessionID = FixtureSessions.bugReport.id
    return InfoPanel()
        .environment(model)
        .frame(width: 280, height: 900)
}

#Preview("Nothing Selected") {
    InfoPanel()
        .environment(AppModel.preview(.waiting))
        .frame(width: 280, height: 400)
}
