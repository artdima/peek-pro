import AppKit
import Observation
import UniformTypeIdentifiers

/// State shared by the window and the menus; in Phase 3 `store` becomes the real session store.
@Observable
final class AppModel {
    let store: MockStore
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
    var isConfirmingClear = false
    /// Off by default: new requests shouldn't pull the list away from what you're reading.
    var isFollowing = false {
        didSet {
            unseenBaseline = isFollowing ? nil : selectedEntries.count
            if isFollowing { scrollToLatestRequest += 1 }
        }
    }
    /// How many requests the session had when Follow was switched off.
    private(set) var unseenBaseline: Int?
    /// Bumped to ask the list to scroll to the newest request.
    private(set) var scrollToLatestRequest = 0
    var viewMode = ConsoleViewMode(rawValue: UserDefaults.standard.string(forKey: ConsoleViewMode.storageKey) ?? "") ?? .table {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: ConsoleViewMode.storageKey) }
    }
    private(set) var recentFiles = RecentFiles(defaults: .standard) {
        didSet { recentFiles.save(to: .standard) }
    }
    var fileOpenError: FileOpenError?
    var listGrouping = ConsoleListGrouping(rawValue: UserDefaults.standard.string(forKey: ConsoleListGrouping.storageKey) ?? "") ?? .status {
        didSet { UserDefaults.standard.set(listGrouping.rawValue, forKey: ConsoleListGrouping.storageKey) }
    }

    init(store: MockStore = MockStore()) {
        self.store = store
        selectedSessionID = store.sessionIDs.first
        markAllSeen()
    }

    func selectScenario(_ scenario: MockScenario) {
        store.select(scenario)
        selectedSessionID = store.sessionIDs.first
        markAllSeen()
    }

    private func markAllSeen() {
        unseenBaseline = isFollowing ? nil : selectedEntries.count
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

    func open(_ urls: [URL]) {
        for url in urls { open(url) }
    }

    func open(_ url: URL) {
        Task {
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try PeekFileLoader.load(url)
                }.value
                store.addFile(loaded.file, entries: loaded.entries)
                selectedSessionID = loaded.file.id
                if let bookmark = loaded.bookmark {
                    recentFiles.add(RecentFile(url: url, bookmark: bookmark))
                }
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            } catch {
                fileOpenError = FileOpenError(name: url.lastPathComponent, message: error.localizedDescription)
            }
        }
    }

    func openRecent(_ recent: RecentFile) {
        guard let url = RecentFiles.resolve(recent.bookmark) else {
            recentFiles.remove(recent.url)
            fileOpenError = FileOpenError(name: recent.name, message: "The file was moved or deleted.")
            return
        }
        open(url)
    }

    func clearRecentFiles() {
        recentFiles.clear()
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.peekSession]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose Peek sessions to open."
        guard panel.runModal() == .OK else { return }
        open(panel.urls)
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

    /// Jumps to the newest request once; Follow stays as it was.
    func showLatest() {
        markAllSeen()
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

    enum RemoteBodyAvailability {
        case available
        case offline
        case notInFile
    }

    var remoteBodyAvailability: RemoteBodyAvailability {
        guard let id = selectedSessionID else { return .notInFile }
        if store.file(id) != nil { return .notInFile }
        return store.session(id)?.connection == .disconnected ? .offline : .available
    }

    var selectedDeviceName: String {
        selectedLiveSession?.title ?? "the device"
    }

    func loadBody(_ key: PeekBodyLoadKey) {
        guard let id = selectedSessionID else { return }
        store.loadBody(key, in: id)
    }

    func reveal(_ id: PeekId) {
        selectedEntryIDs = [id]
    }

    var windowTitle: String {
        guard let id = selectedSessionID else { return "Peek Pro" }
        if let file = store.file(id) { return file.name }
        return store.session(id)?.title ?? "Peek Pro"
    }

    var windowSubtitle: String {
        guard let id = selectedSessionID, let info = store.info(for: id) else { return "" }
        if store.file(id) != nil { return [info.name, info.systemTitle].compactMap(\.self).joined(separator: " · ") }
        guard let session = store.session(id) else { return info.systemTitle }
        return info.name == nil ? info.systemTitle : "\(info.systemTitle) · \(session.address)"
    }
}

struct FileOpenError: Identifiable {
    let id = UUID()
    let name: String
    let message: String
}
