import SwiftUI

/// Pulse Pro's toolbar: source, recording, follow and clear on the left, view controls in the middle.
struct ConsoleToolbar: ToolbarContent {
    @Bindable var model: AppModel
    @Binding var detailPlacement: DetailPlacement
    @Binding var isConfirmingClear: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            SessionPicker(model: model)
            if let session = model.selectedLiveSession {
                let isPaused = model.store.isPaused(session.id)
                Button {
                    model.store.togglePaused(session.id)
                } label: {
                    Label(isPaused ? "Resume Recording" : "Pause Recording",
                          systemImage: isPaused ? "play.fill" : "pause.fill")
                }
                .help(isPaused ? "Resume recording" : "Pause recording")
                .disabled(session.connection == .disconnected)

                Toggle(isOn: $model.isFollowing) {
                    Label("Follow", systemImage: "clock")
                }
                .toggleStyle(.button)
                .help(model.isFollowing ? "Stop scrolling to new requests" : "Scroll to new requests as they arrive")

                Button {
                    isConfirmingClear = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .help("Clear requests")
                .disabled(model.selectedEntries.isEmpty)
            }
        }

        ToolbarItemGroup(placement: .principal) {
            Picker("View", selection: $model.viewMode) {
                ForEach(ConsoleViewMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("Show requests as a table or a list")

            if model.viewMode == .list {
                ListGroupingMenu(grouping: $model.listGrouping)
            }

            DetailPlacementMenu(placement: $detailPlacement)

            ExportMenu(hasEntries: !model.filteredEntries.isEmpty)
        }

        ToolbarItem(placement: .primaryAction) {
            ConnectionButton(model: model)
        }
    }
}

private struct SessionPicker: View {
    @Bindable var model: AppModel

    var body: some View {
        Menu {
            Picker("Session", selection: $model.selectedSessionID) {
                if !model.store.sessions.isEmpty {
                    Section("Devices") {
                        ForEach(model.store.sessions) { session in
                            Label("\(session.info.device.name) — \(session.info.app.name)",
                                  systemImage: session.info.device.symbolName)
                                .tag(session.id as PeekSessionID?)
                        }
                    }
                }
                if !model.store.files.isEmpty {
                    Section("Files") {
                        ForEach(model.store.files) { file in
                            Label(file.name, systemImage: "doc.text")
                                .tag(file.id as PeekSessionID?)
                        }
                    }
                }
            }
            .pickerStyle(.inline)
        } label: {
            label
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(model.store.sessionIDs.isEmpty)
        .help("Choose a device or a file")
    }

    @ViewBuilder
    private var label: some View {
        if let id = model.selectedSessionID, let file = model.store.file(id) {
            Label(file.name, systemImage: "doc.text")
                .labelStyle(.titleAndIcon)
        } else if let session = model.selectedLiveSession {
            HStack(spacing: 6) {
                Image(systemName: session.info.device.symbolName)
                Text(session.info.device.name)
                Text("(\(session.info.device.systemTitle))")
                    .foregroundStyle(.secondary)
                ConnectionDot(state: session.connection)
            }
        } else {
            Label("No Session", systemImage: "iphone.slash")
                .labelStyle(.titleAndIcon)
        }
    }
}

private struct ExportMenu: View {
    let hasEntries: Bool

    var body: some View {
        Menu {
            Button("Export as HAR…") {}
            Button("Save as Peek Session…") {}
            Button("Copy as Text") {}
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .menuIndicator(.hidden)
        // Exporters arrive in Phase 4; the menu is here so the toolbar can be judged as a whole.
        .disabled(true)
        .help(hasEntries ? "Export" : "Nothing to export")
    }
}

private struct ConnectionButton: View {
    let model: AppModel
    @State private var isPresented = false

    private var server: PeekServerState { model.store.server }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Connection", systemImage: "antenna.radiowaves.left.and.right")
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(server.status == .listening ? Color(.statusSuccess) : .orange)
                        .frame(width: 6, height: 6)
                        .offset(x: 3, y: 2)
                }
        }
        .help(server.status == .listening ? "Listening on port \(server.port)" : "Port \(server.port) is in use")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ConnectionPopover(model: model)
        }
    }
}

private struct ConnectionPopover: View {
    let model: AppModel

    private var server: PeekServerState { model.store.server }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(server.status == .listening ? Color(.statusSuccess) : .orange)
                    .frame(width: 8, height: 8)
                Text(server.status == .listening ? "Listening on port \(server.port)" : "Port \(server.port) is in use")
                    .font(.headline)
            }
            if let name = server.bonjourName {
                Text("Advertised as “\(name)”")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                ForEach(server.addresses, id: \.self) { address in
                    GridRow {
                        Text("Address")
                            .foregroundStyle(.secondary)
                        Text("\(address):\(server.port)")
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        CopyButton(text: "\(address):\(server.port)")
                    }
                }
                GridRow {
                    Text("Token")
                        .foregroundStyle(.secondary)
                    Text(server.token)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    HStack(spacing: 2) {
                        CopyButton(text: server.token)
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
            Text("Devices connect with this address and token. Change the port in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 340)
    }
}
