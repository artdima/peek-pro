import AppKit
import SwiftUI

struct SessionsPanel: View {
    @Environment(AppModel.self) private var model

    private var store: MockStore { model.store }

    var body: some View {
        Group {
            if store.sessions.isEmpty && store.files.isEmpty {
                WaitingForDevicesView()
            } else {
                sessionList
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ServerStatusFooter(server: store.server)
        }
    }

    private var sessionList: some View {
        @Bindable var model = model
        return List(selection: $model.selectedSessionID) {
            ForEach(appGroups) { group in
                Section {
                    ForEach(group.sessions) { session in
                        LiveSessionRow(session: session, count: store.entries(in: session.id).count)
                            .tag(session.id)
                            .contextMenu { liveSessionMenu(session) }
                    }
                } header: {
                    AppHeader(app: group.app)
                }
            }
            if !store.files.isEmpty {
                Section("Files") {
                    ForEach(store.files) { file in
                        SessionFileRow(file: file, count: store.entries(in: file.id).count)
                            .tag(file.id)
                            .contextMenu { fileMenu(file) }
                    }
                }
            }
            if !store.rejected.isEmpty {
                Section("Rejected") {
                    ForEach(store.rejected) { connection in
                        RejectedConnectionRow(connection: connection)
                            .selectionDisabled()
                            .contextMenu {
                                if connection.reason == .invalidToken {
                                    Button("Copy Current Token") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(store.server.token, forType: .string)
                                    }
                                }
                                Button("Dismiss") { store.dismissRejected(connection.id) }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var appGroups: [AppGroup] {
        var groups: [AppGroup] = []
        for session in store.sessions {
            if let index = groups.firstIndex(where: { $0.app.identifier == session.info.app.identifier }) {
                groups[index].sessions.append(session)
            } else {
                groups.append(AppGroup(app: session.info.app, sessions: [session]))
            }
        }
        return groups
    }

    @ViewBuilder
    private func liveSessionMenu(_ session: PeekLiveSession) -> some View {
        if session.connection != .disconnected {
            Button("Disconnect") { store.disconnect(session.id) }
        }
        Divider()
        Button("Remove from List", role: .destructive) { model.removeSession(session.id) }
    }

    @ViewBuilder
    private func fileMenu(_ file: PeekSessionFile) -> some View {
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
        Divider()
        Button("Close") { model.closeFile(file.id) }
    }
}

private struct AppGroup: Identifiable {
    let app: PeekApp
    var sessions: [PeekLiveSession]

    var id: String { app.identifier }
}

#Preview("Live") {
    SessionsPanel()
        .environment(AppModel.preview(.live))
        .frame(width: 270, height: 560)
}

#Preview("Disconnected — Dark") {
    SessionsPanel()
        .environment(AppModel.preview(.disconnected))
        .frame(width: 270, height: 560)
        .preferredColorScheme(.dark)
}

#Preview("Files") {
    SessionsPanel()
        .environment(AppModel.preview(.file))
        .frame(width: 270, height: 560)
}
