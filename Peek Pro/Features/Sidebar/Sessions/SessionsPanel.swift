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
            if !store.sessions.isEmpty {
                Section("Devices") {
                    ForEach(store.sessions) { session in
                        LiveSessionRow(session: session, count: store.entries(in: session.id).count)
                            .tag(session.id)
                            .contextMenu { liveSessionMenu(session) }
                    }
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

#Preview("Live") {
    SessionsPanel()
        .environment(AppModel.preview(.live))
        .frame(width: 290, height: 560)
}

#Preview("Disconnected — Dark") {
    SessionsPanel()
        .environment(AppModel.preview(.disconnected))
        .frame(width: 290, height: 560)
        .preferredColorScheme(.dark)
}

#Preview("Files") {
    SessionsPanel()
        .environment(AppModel.preview(.file))
        .frame(width: 290, height: 560)
}
