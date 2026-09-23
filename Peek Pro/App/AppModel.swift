import AppKit
import Observation
import UniformTypeIdentifiers

/// State shared by the window and the menus.
@Observable
final class AppModel {
    let store: SessionHub
    /// Mock devices and states for previews and the Debug menu; never in release.
    let mocks: MockFeed?
    /// Nil in previews and tests, which show the fixture server instead.
    let remote: PeekRemoteHost?
    var selectedSessionID: PeekSessionID? {
        didSet {
            guard oldValue != selectedSessionID else { return }
            selectedEntryIDs = []
            if !isFollowing { unseenBaseline = selectedEntries.count }
        }
    }
    var selectedEntryIDs: Set<PeekId> = []
    /// What the Filters panel sets; search and the time window are added in `filteredEntries`.
    var filter = PeekFilter()
    var timeWindow = ConsoleTimeWindow.any
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
    private(set) var recentFiles = FileBookmarks.recent() {
        didSet { recentFiles.save() }
    }
    @ObservationIgnored private var openFiles = FileBookmarks.open() {
        didSet { openFiles.save() }
    }
    var fileOpenError: FileOpenError?
    @ObservationIgnored private var selection = ConsoleSelection()
    @ObservationIgnored private var derived = ConsoleDerived()
    var listGrouping = ConsoleListGrouping(rawValue: UserDefaults.standard.string(forKey: ConsoleListGrouping.storageKey) ?? "") ?? .status {
        didSet { UserDefaults.standard.set(listGrouping.rawValue, forKey: ConsoleListGrouping.storageKey) }
    }

    init(scenario: MockScenario? = nil, isLive: Bool = true, restoresOpenFiles: Bool = true, servesDevices: Bool = false) {
        let store = SessionHub()
        self.store = store
        let remote = servesDevices ? PeekRemoteHost(hub: store) : nil
        self.remote = remote
        mocks = scenario.map { MockFeed(hub: store, scenario: $0, isLive: isLive, fakesServer: remote == nil) }
        remote?.start()
        selectedSessionID = store.sessionIDs.first
        markAllSeen()
        if restoresOpenFiles { reopenFiles() }
        remote?.sessions.onOpen = { [weak self] id in
            guard let self, self.selectedSessionID == nil else { return }
            self.selectedSessionID = id
        }
        if let remote {
            // Real devices first; a mock session falls through to the mock loader.
            let mockLoader = store.bodyLoader
            store.bodyLoader = { [weak remote, weak store] key, id in
                if remote?.sessions.loadBody(key, in: id) == true { return }
                if let mockLoader { return mockLoader(key, id) }
                store?.failBodyLoad(key, in: id, message: "The device isn't connected.")
            }
        }
    }

    func selectScenario(_ scenario: MockScenario) {
        mocks?.select(scenario)
        if scenario != .portInUse { remote?.publish() }
        selectedSessionID = store.sessionIDs.first
        markAllSeen()
    }

    /// The device must pair again; mocks only lose the row.
    func forgetDevice(_ id: String) {
        if let remote { remote.sessions.forgetDevice(id) } else { store.removePairedDevice(id) }
    }

    func forgetAllDevices() {
        if let remote { remote.sessions.forgetAllDevices() } else { store.pairedDevices.map(\.id).forEach(store.removePairedDevice) }
    }

    /// A new pairing code; the real server also forgets the wrong tries against the old one.
    func newPairingCode() {
        if let remote { remote.sessions.rotateCode() } else { store.rotatePairingCode() }
    }

    /// After Settings changed the port or the Bonjour name.
    func applyServerSettings() {
        store.applyServerSettings()
        remote?.applySettings()
    }

    private func markAllSeen() {
        unseenBaseline = isFollowing ? nil : selectedEntries.count
    }

    /// Real devices are closed and kept from coming back; mock ones are only marked.
    func disconnect(_ id: PeekSessionID) {
        if remote?.sessions.disconnect(id) != true { store.disconnect(id) }
    }

    func removeSession(_ id: PeekSessionID) {
        // Left connected, a removed session would keep receiving into a store nobody shows.
        remote?.sessions.disconnect(id)
        store.removeSession(id)
        keepSelectionValid()
    }

    func closeFile(_ id: PeekSessionID) {
        store.closeFile(id)
        if case .file(let url) = id { openFiles.remove(url) }
        keepSelectionValid()
    }

    func openDemoFiles() {
        store.addDemoFiles()
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
                    recentFiles.add(FileBookmark(url: url, bookmark: bookmark))
                    openFiles.add(FileBookmark(url: url, bookmark: bookmark))
                }
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            } catch {
                fileOpenError = FileOpenError(name: url.lastPathComponent, message: error.localizedDescription)
            }
        }
    }

    func openRecent(_ recent: FileBookmark) {
        guard let url = FileBookmarks.resolve(recent.bookmark) else {
            recentFiles.remove(recent.url)
            fileOpenError = FileOpenError(name: recent.name, message: "The file was moved or deleted.")
            return
        }
        open(url)
    }

    func clearRecentFiles() {
        recentFiles.clear()
    }

    /// Reads back the files that were open at quit, in their order; one that is gone is dropped quietly.
    private func reopenFiles() {
        let bookmarks = openFiles.items
        guard !bookmarks.isEmpty else { return }
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                bookmarks.map { bookmark in
                    FileBookmarks.resolve(bookmark.bookmark).flatMap { try? PeekFileLoader.load($0) }
                }
            }.value
            for (bookmark, file) in zip(bookmarks, loaded) {
                guard let file else {
                    openFiles.remove(bookmark.url)
                    continue
                }
                store.addFile(file.file, entries: file.entries, atTop: false)
                if let fresh = file.bookmark, fresh != bookmark.bookmark {
                    openFiles.replace(bookmark.url, with: FileBookmark(url: file.file.url, bookmark: fresh))
                }
            }
            if selectedSessionID == nil { selectedSessionID = store.sessionIDs.first }
        }
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

    var searchQuery: PeekSearchQuery {
        PeekSearchQuery(searchText, scopes: searchScope.scopes)
    }

    var urlHighlight: String {
        searchQuery.scopes.contains(.url) ? searchQuery.trimmedText : ""
    }

    var hasFilters: Bool { !filter.isEmpty || timeWindow != .any }

    func resetFilters() {
        filter = PeekFilter()
        timeWindow = .any
    }

    /// Filters and search; the quick modes count within this. Updated incrementally as the session changes.
    var filteredEntries: [PeekEntry] {
        let sessionStore = selectedSessionID.flatMap { store.store($0) }
        var effective = filter
        effective.dates = timeWindow.dates(latest: sessionStore?.latestStart)
        effective.query = searchQuery
        selection.update(from: sessionStore, filter: effective)
        return selection.entries
    }

    var visibleEntries: [PeekEntry] {
        let filtered = filteredEntries
        guard quickMode != .all else { return filtered }
        let key = ConsoleDerived.Key(generation: selection.generation, mode: quickMode)
        if let cached = derived.visible, cached.key == key { return cached.entries }
        let entries = filtered.filter(quickMode.matches)
        derived.visible = (key, entries)
        return entries
    }

    func count(of mode: ConsoleQuickMode) -> Int {
        let filtered = filteredEntries
        if let cached = derived.counts, cached.generation == selection.generation { return cached.counts[mode] ?? 0 }
        var counts: [ConsoleQuickMode: Int] = [.all: filtered.count]
        for entry in filtered {
            for mode in ConsoleQuickMode.allCases where mode != .all && mode.matches(entry) {
                counts[mode, default: 0] += 1
            }
        }
        derived.counts = (selection.generation, counts)
        return counts[mode] ?? 0
    }

    /// The table's rows, and the newest request wherever the sort put it — for Follow.
    func tableRows(sortedBy sort: ConsoleSort) -> (rows: [PeekEntry], newest: PeekId?) {
        let visible = visibleEntries
        let key = ConsoleDerived.Key(generation: selection.generation, mode: quickMode)
        if let cached = derived.rows, cached.key == key, cached.sort == sort { return (cached.rows, cached.newest) }
        let rows = sort.apply(visible)
        let newest = sort == .default ? rows.last?.id : visible.max { $0.startedAt < $1.startedAt }?.id
        derived.rows = (key, sort, rows, newest)
        return (rows, newest)
    }

    var newestVisibleID: PeekId? {
        let visible = visibleEntries
        let key = ConsoleDerived.Key(generation: selection.generation, mode: quickMode)
        if let cached = derived.newest, cached.key == key { return cached.id }
        let id = visible.max { $0.startedAt < $1.startedAt }?.id
        derived.newest = (key, id)
        return id
    }

    var listSections: [ConsoleListSection] {
        let visible = visibleEntries
        let key = ConsoleDerived.Key(generation: selection.generation, mode: quickMode)
        if let cached = derived.sections, cached.key == key, cached.grouping == listGrouping { return cached.sections }
        let sections = listGrouping.sections(of: visible)
        derived.sections = (key, listGrouping, sections)
        return sections
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
        guard selectedEntryIDs.count == 1, let id = selectedEntryIDs.first, let sessionID = selectedSessionID else { return nil }
        return store.entry(id, in: sessionID)
    }

    var issues: [SessionIssue] {
        let dropped = selectedSessionID.flatMap { store.session($0) }?.droppedCount ?? 0
        return SessionIssue.issues(in: selectedEntries, droppedCount: dropped)
    }

    enum RemoteBodyAvailability {
        case available
        case offline
        case notInFile
    }

    func remoteBodyAvailability(in id: PeekSessionID?) -> RemoteBodyAvailability {
        guard let id else { return .notInFile }
        if store.file(id) != nil { return .notInFile }
        return store.session(id)?.connection == .disconnected ? .offline : .available
    }

    func deviceName(in id: PeekSessionID?) -> String {
        id.flatMap { store.session($0)?.title } ?? "the device"
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

/// What the console derives from the selection; each part is rebuilt only when its inputs change.
private struct ConsoleDerived {
    struct Key: Equatable {
        let generation: Int
        let mode: ConsoleQuickMode
    }

    var visible: (key: Key, entries: [PeekEntry])?
    var counts: (generation: Int, counts: [ConsoleQuickMode: Int])?
    var rows: (key: Key, sort: ConsoleSort, rows: [PeekEntry], newest: PeekId?)?
    var sections: (key: Key, grouping: ConsoleListGrouping, sections: [ConsoleListSection])?
    var newest: (key: Key, id: PeekId?)?
}
