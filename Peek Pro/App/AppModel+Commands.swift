import AppKit

/// What the menus act on: the requests selected in the main window and the session they belong to.
extension AppModel {
    var commandEntries: [PeekEntry] {
        selectedEntries.filter { selectedEntryIDs.contains($0.id) }
    }

    func copyURLs() {
        copy(commandEntries.map(\.request.uri.absoluteString).joined(separator: "\n"))
    }

    func copyCurl() {
        guard let entry = selectedEntry else { return }
        copy(MockExport.curl(entry))
    }

    func togglePinForSelection() {
        guard let sessionID = selectedSessionID else { return }
        let entries = commandEntries
        let allPinned = entries.allSatisfy(\.isPinned)
        for entry in entries where entry.isPinned == allPinned {
            store.togglePin(entry.id, in: sessionID)
        }
    }

    var canPauseSelectedSession: Bool {
        guard let session = selectedLiveSession else { return false }
        return session.connection != .disconnected
    }

    var isSelectedSessionPaused: Bool {
        selectedSessionID.map { store.isPaused($0) } ?? false
    }

    func togglePauseForSelectedSession() {
        guard let id = selectedSessionID, canPauseSelectedSession else { return }
        store.togglePaused(id)
    }

    func disconnectSelectedSession() {
        guard let id = selectedSessionID else { return }
        store.disconnect(id)
    }

    func openRecent(_ file: PeekSessionFile) {
        store.openDemoFiles()
        selectedSessionID = file.id
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
