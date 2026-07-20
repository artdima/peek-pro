import AppKit

/// What the menus act on: the requests selected in the main window and the session they belong to.
extension AppModel {
    var commandEntries: [PeekEntry] {
        selectedSessionID.map { store.entries(selectedEntryIDs, in: $0) } ?? []
    }

    func copyURLs() {
        copy(commandEntries.map(\.request.uri.absoluteString).joined(separator: "\n"))
    }

    func copyCurl() {
        guard let entry = selectedEntry else { return }
        copy(PeekExporters.curl.export(entry))
    }

    func togglePinForSelection() {
        togglePin(selectedEntryIDs)
    }

    /// Pins them all unless every one is already pinned — then unpins them all, as Finder does with tags.
    func togglePin(_ ids: Set<PeekId>) {
        guard let sessionID = selectedSessionID, !ids.isEmpty else { return }
        let entries = store.entries(ids, in: sessionID)
        store.setPinned(ids, to: !entries.allSatisfy(\.isPinned), in: sessionID)
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

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
