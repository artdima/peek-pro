import Foundation
import Observation

/// State shared by the window and the menus; in Phase 3 `store` becomes the real session store.
@Observable
final class AppModel {
    let store: MockStore
    var panel: SidebarPanel = .sessions
    var selectedSessionID: PeekSessionID? {
        didSet { if oldValue != selectedSessionID { selectedEntryIDs = [] } }
    }
    var selectedEntryIDs: Set<PeekId> = []
    var filter = ConsoleFilter()
    var searchText = ""
    var isFollowing = true
    var viewMode = ConsoleViewMode(rawValue: UserDefaults.standard.string(forKey: ConsoleViewMode.storageKey) ?? "") ?? .table {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: ConsoleViewMode.storageKey) }
    }

    init(store: MockStore = MockStore()) {
        self.store = store
        selectedSessionID = store.sessionIDs.first
    }

    func selectScenario(_ scenario: MockScenario) {
        store.select(scenario)
        selectedSessionID = store.sessionIDs.first
    }

    func showInfo(_ id: PeekSessionID) {
        selectedSessionID = id
        panel = .info
    }

    func removeSession(_ id: PeekSessionID) {
        store.removeSession(id)
        keepSelectionValid()
    }

    func closeFile(_ id: PeekSessionID) {
        store.closeFile(id)
        keepSelectionValid()
    }

    func openDemoFiles() {
        store.openDemoFiles()
        selectedSessionID = store.files.first?.id
    }

    private func keepSelectionValid() {
        if let id = selectedSessionID, store.sessionIDs.contains(id) { return }
        selectedSessionID = store.sessionIDs.first
    }

    var selectedEntries: [PeekEntry] {
        selectedSessionID.map { store.entries(in: $0) } ?? []
    }

    var selectedLiveSession: PeekLiveSession? {
        selectedSessionID.flatMap { store.session($0) }
    }

    /// Matches the URL only; scopes for headers, bodies and errors come with the full search field.
    var filteredEntries: [PeekEntry] {
        let filtered = filter.apply(selectedEntries)
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return filtered }
        return filtered.filter { $0.request.uri.absoluteString.localizedCaseInsensitiveContains(query) }
    }

    var selectedEntry: PeekEntry? {
        guard selectedEntryIDs.count == 1, let id = selectedEntryIDs.first else { return nil }
        return selectedEntries.first { $0.id == id }
    }

    var issues: [ConsoleIssue] {
        let dropped = selectedSessionID.flatMap { store.session($0) }?.droppedCount ?? 0
        return ConsoleIssue.issues(in: selectedEntries, droppedCount: dropped)
    }

    func reveal(_ id: PeekId) {
        selectedEntryIDs = [id]
    }

    var windowTitle: String {
        guard let id = selectedSessionID else { return "Peek Pro" }
        if let file = store.file(id) { return file.name }
        return store.info(for: id)?.app.name ?? "Peek Pro"
    }

    var windowSubtitle: String {
        guard let id = selectedSessionID, let info = store.info(for: id) else { return "" }
        if store.file(id) != nil { return "\(info.app.name) · \(info.device.name)" }
        return "\(info.device.name) · \(info.device.systemTitle)"
    }
}
