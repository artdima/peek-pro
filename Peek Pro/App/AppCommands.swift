import AppKit
import SwiftUI

struct AppCommands: Commands {
    let model: AppModel

    @Environment(\.openWindow) private var openWindow
    @AppStorage(DetailPlacement.storageKey) private var detailPlacement: DetailPlacement = .bottom
    /// Where the details go back to when shown again with ⇧⌘D.
    @AppStorage("detailPlacement.lastVisible") private var lastVisiblePlacement: DetailPlacement = .bottom

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Peek Pro") { AboutPanel.show() }
        }
        fileCommands
        viewCommands
        requestMenu
        sessionMenu
        helpCommands
    }

    private var fileCommands: some Commands {
        Group {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { model.showOpenPanel() }
                    .keyboardShortcut("o")
                Menu("Open Recent") {
                    ForEach(model.recentFiles.items) { recent in
                        Button(recent.name) { model.openRecent(recent) }
                    }
                    Divider()
                    Button("Clear Menu") { model.clearRecentFiles() }
                        .disabled(model.recentFiles.items.isEmpty)
                }
            }
            CommandGroup(after: .saveItem) {
                Menu("Export") {
                    Button("HAR…") { model.exportHAR(model.visibleEntries) }
                    Button("Peek Session…") {}
                        .disabled(true)
                    Button("Text…") { model.exportText(model.visibleEntries) }
                }
                .disabled(model.visibleEntries.isEmpty)
                if let id = model.selectedSessionID, model.store.file(id) != nil {
                    Button("Close File") { model.closeFile(id) }
                }
            }
            CommandGroup(replacing: .printItem) {}
        }
    }

    private var viewCommands: some Commands {
        CommandGroup(after: .sidebar) {
            Section {
                Toggle("As Table", isOn: binding(\.viewMode, .table))
                    .keyboardShortcut("1", modifiers: [.control, .command])
                Toggle("As List", isOn: binding(\.viewMode, .list))
                    .keyboardShortcut("2", modifiers: [.control, .command])
            }
            Section {
                Toggle("Details at Bottom", isOn: placementBinding(.bottom))
                Toggle("Details on Right", isOn: placementBinding(.right))
                Button(detailPlacement == .hidden ? "Show Details" : "Hide Details") {
                    if detailPlacement == .hidden {
                        detailPlacement = lastVisiblePlacement
                    } else {
                        lastVisiblePlacement = detailPlacement
                        detailPlacement = .hidden
                    }
                }
                .keyboardShortcut("d", modifiers: [.shift, .command])
            }
        }
    }

    private var requestMenu: some Commands {
        CommandMenu("Request") {
            let entries = model.commandEntries
            let single = model.selectedEntry
            Button(!entries.isEmpty && entries.allSatisfy(\.isPinned) ? "Unpin" : "Pin") {
                model.togglePinForSelection()
            }
            .keyboardShortcut("p")
            .disabled(entries.isEmpty)

            Divider()

            Button(entries.count > 1 ? "Copy URLs" : "Copy URL") { model.copyURLs() }
                .keyboardShortcut("c", modifiers: [.shift, .command])
                .disabled(entries.isEmpty)
            Button("Copy as cURL") { model.copyCurl() }
                .keyboardShortcut("c", modifiers: [.option, .command])
                .disabled(single == nil)

            Divider()

            Button("Open in New Window") {
                OpenEntryWindowsAction(model: model, openWindow: openWindow)(entries.map(\.id))
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(entries.isEmpty)
        }
    }

    private var sessionMenu: some Commands {
        CommandMenu("Session") {
            Button(model.isSelectedSessionPaused ? "Resume Recording" : "Pause Recording") {
                model.togglePauseForSelectedSession()
            }
            .keyboardShortcut("r")
            .disabled(!model.canPauseSelectedSession)

            Toggle("Follow New Requests", isOn: Binding(
                get: { model.isFollowing },
                set: { model.isFollowing = $0 }
            ))
            .disabled(model.selectedLiveSession == nil)

            Button("Clear…") { model.isConfirmingClear = true }
                .keyboardShortcut("k")
                .disabled(model.selectedLiveSession == nil || model.selectedEntries.isEmpty)

            Divider()

            Button("Disconnect") { model.disconnectSelectedSession() }
                .disabled(!model.canPauseSelectedSession)
        }
    }

    private var helpCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button("Peek on GitHub") {
                NSWorkspace.shared.open(AboutPanel.peekRepository)
            }
        }
    }

    private func binding<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<AppModel, Value>, _ value: Value) -> Binding<Bool> {
        Binding(
            get: { model[keyPath: keyPath] == value },
            set: { if $0 { model[keyPath: keyPath] = value } }
        )
    }

    private func placementBinding(_ placement: DetailPlacement) -> Binding<Bool> {
        Binding(
            get: { detailPlacement == placement },
            set: { if $0 { detailPlacement = placement } }
        )
    }
}
