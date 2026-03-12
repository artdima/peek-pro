import Foundation
import Observation

/// State shared by the window and the menus; in Phase 3 `store` becomes the real session store.
@Observable
final class AppModel {
    let store: MockStore
    var panel: SidebarPanel = .sessions
    var selectedSessionID: PeekSessionID? {
        didSet {
            guard oldValue != selectedSessionID else { return }
            selectedEntryIDs = []
            if !isFollowing { unseenBaseline = selectedEntries.count }
        }
    }
    var selectedEntryIDs: Set<PeekId> = []
    var filter = ConsoleFilter()
    var searchText = ""
    var searchScope = ConsoleSearchScope.all
    var quickMode = ConsoleQuickMode.all
    var isFollowing = true {
        didSet { unseenBaseline = isFollowing ? nil : selectedEntries.count }
    }
    /// How many requests the session had when Follow was switched off.
    private(set) var unseenBaseline: Int?
    /// Bumped to ask the list to scroll to the newest request.
    private(set) var scrollToLatestRequest = 0
    var viewMode = ConsoleViewMode(rawValue: UserDefaults.standard.string(forKey: ConsoleViewMode.storageKey) ?? "") ?? .table {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: ConsoleViewMode.storageKey) }
    }
    var listGrouping = ConsoleListGrouping(rawValue: UserDefaults.standard.string(forKey: ConsoleListGrouping.storageKey) ?? "") ?? .status {
        didSet { UserDefaults.standard.set(listGrouping.rawValue, forKey: ConsoleListGrouping.storageKey) }
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

    var search: ConsoleSearch {
        ConsoleSearch(text: searchText, scope: searchScope)
    }

    var urlHighlight: String {
        searchScope == .all || searchScope == .url ? search.query : ""
    }

    /// Filters and search; the quick modes count within this.
    var filteredEntries: [PeekEntry] {
        let search = search
        let filtered = filter.apply(selectedEntries)
        return search.query.isEmpty ? filtered : filtered.filter { search.matches($0) }
    }

    var visibleEntries: [PeekEntry] {
        let entries = filteredEntries
        return quickMode == .all ? entries : entries.filter { quickMode.matches($0) }
    }

    var unseenCount: Int {
        guard let unseenBaseline else { return 0 }
        return max(0, selectedEntries.count - unseenBaseline)
    }

    func showLatest() {
        isFollowing = true
        scrollToLatestRequest += 1
    }

    func clearSelectedSession() {
        guard let id = selectedSessionID else { return }
        store.clear(id)
        selectedEntryIDs = []
        if !isFollowing { unseenBaseline = 0 }
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
