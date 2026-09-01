import Foundation
import Observation

/// Every source the window shows: live devices, `.peek` files, and the server they connect to.
/// Screens read it and act through it; what feeds it — the mock scenarios now, the WebSocket server
/// — uses the feeding half below.
@Observable
final class SessionHub {
    private(set) var server: PeekServerState
    private(set) var sessions: [PeekLiveSession] = []
    private(set) var files: [PeekSessionFile] = []
    private(set) var rejected: [PeekRejectedConnection] = []
    private(set) var paused: Set<PeekSessionID> = []
    private(set) var bodyLoads: [PeekBodyLoadKey: PeekBodyLoadState] = [:]
    private var stores: [PeekSessionID: SessionStore] = [:]

    /// Files the user opened, as opposed to demo ones: `reset()` keeps them.
    @ObservationIgnored private var openedFileIDs: Set<PeekSessionID> = []
    /// Fetches a body that stayed on the device; nobody can until a device connection exists.
    @ObservationIgnored var bodyLoader: ((PeekBodyLoadKey, PeekSessionID) -> Void)?

    init(server: PeekServerState = PeekServerState(
        status: .listening,
        port: PeekServerState.defaultPort,
        addresses: [],
        bonjourName: nil,
        token: PeekServerState.launchToken(
            policy: TokenPolicy.current,
            stored: UserDefaults.standard.string(forKey: SettingsKey.token)
        )
    )) {
        self.server = server
        applyServerSettings()
        applyTokenPolicy()
    }

    // MARK: Reading

    var sessionIDs: [PeekSessionID] {
        sessions.map(\.id) + files.map(\.id)
    }

    func entries(in id: PeekSessionID) -> [PeekEntry] {
        stores[id]?.entries ?? []
    }

    func entry(_ entryID: PeekId, in id: PeekSessionID) -> PeekEntry? {
        stores[id]?.entry(entryID)
    }

    /// Copy-on-write, so reading the whole store costs nothing until it changes.
    func store(_ id: PeekSessionID) -> SessionStore? {
        stores[id]
    }

    /// In the order they arrived; ids that aren't in the session are skipped.
    func entries(_ entryIDs: Set<PeekId>, in id: PeekSessionID) -> [PeekEntry] {
        guard let store = stores[id] else { return [] }
        return entryIDs.compactMap(store.position(of:)).sorted().map { store.entries[$0] }
    }

    func session(_ id: PeekSessionID) -> PeekLiveSession? {
        sessions.first { $0.id == id }
    }

    func file(_ id: PeekSessionID) -> PeekSessionFile? {
        files.first { $0.id == id }
    }

    func info(for id: PeekSessionID) -> PeekSessionInfo? {
        session(id)?.info ?? file(id)?.info
    }

    func isPaused(_ id: PeekSessionID) -> Bool {
        paused.contains(id)
    }

    // MARK: Acting

    func togglePaused(_ id: PeekSessionID) {
        if paused.contains(id) { paused.remove(id) } else { paused.insert(id) }
    }

    func clear(_ id: PeekSessionID) {
        stores[id]?.clear()
    }

    /// Pins live in memory only: a file's pins go when it's closed and aren't written into the .peek.
    func setPinned(_ entryIDs: Set<PeekId>, to isPinned: Bool, in id: PeekSessionID) {
        stores[id]?.setPinned(entryIDs, to: isPinned)
    }

    func closeFile(_ id: PeekSessionID) {
        files.removeAll { $0.id == id }
        stores[id] = nil
        openedFileIDs.remove(id)
    }

    func removeSession(_ id: PeekSessionID) {
        sessions.removeAll { $0.id == id }
        stores[id] = nil
        paused.remove(id)
    }

    func disconnect(_ id: PeekSessionID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].connection = .disconnected
        sessions[index].disconnectedAt = .now
    }

    func dismissRejected(_ id: String) {
        rejected.removeAll { $0.id == id }
    }

    /// A file the user opened; opening the same file again replaces it.
    func addFile(_ file: PeekSessionFile, entries: [PeekEntry], atTop: Bool = true) {
        insertFile(file, entries: entries, atTop: atTop)
        openedFileIDs.insert(file.id)
    }

    func loadBody(_ key: PeekBodyLoadKey, in id: PeekSessionID) {
        guard bodyLoads[key] != .loading else { return }
        guard let bodyLoader else {
            bodyLoads[key] = .failed("The device isn't connected.")
            return
        }
        bodyLoads[key] = .loading
        bodyLoader(key, id)
    }

    /// Port and Bonjour name from Settings.
    func applyServerSettings() {
        let defaults = UserDefaults.standard
        let port = defaults.integer(forKey: SettingsKey.port)
        if port > 0 { server.port = port }
        if defaults.object(forKey: SettingsKey.bonjourEnabled) as? Bool == false {
            server.bonjourName = nil
        } else if let name = defaults.string(forKey: SettingsKey.bonjourName), !name.isEmpty {
            server.bonjourName = name
        }
    }

    func regenerateToken() {
        server.token = PeekServerState.newToken()
        applyTokenPolicy()
    }

    /// Remembers the token while the policy keeps it, and forgets it otherwise.
    func applyTokenPolicy() {
        let defaults = UserDefaults.standard
        switch TokenPolicy.current {
        case .persistent: defaults.set(server.token, forKey: SettingsKey.token)
        case .perLaunch: defaults.removeObject(forKey: SettingsKey.token)
        }
    }

    // MARK: Feeding

    /// Drops the files that only stand in for opened ones.
    func removeDemoFiles() {
        for file in files where !openedFileIDs.contains(file.id) { stores[file.id] = nil }
        files.removeAll { !openedFileIDs.contains($0.id) }
    }

    func setServer(_ server: PeekServerState) {
        self.server = server
    }

    /// A session seen before keeps its place, and its entries give way to the history that follows.
    func addSession(_ session: PeekLiveSession, entries: [PeekEntry] = []) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        stores[session.id] = SessionStore(entries: entries)
    }

    /// A device that connected, or came back: a session seen before keeps its place and its entries
    /// until `replaceEntries` brings the history it sent again.
    func connectSession(_ session: PeekLiveSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            var session = session
            session.droppedCount = sessions[index].droppedCount
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        if stores[session.id] == nil { stores[session.id] = SessionStore() }
    }

    /// Everything the device holds, in one go; what the viewer pinned stays pinned.
    func replaceEntries(_ store: SessionStore, in id: PeekSessionID) {
        var store = store
        if let old = stores[id] {
            store.setPinned(old.entries.lazy.filter(\.isPinned).map(\.id), to: true)
        }
        stores[id] = store
    }

    func remove(_ entryID: PeekId, in id: PeekSessionID) {
        stores[id]?.remove(entryID)
    }

    func addDropped(_ count: Int, in id: PeekSessionID) {
        guard count > 0, let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].droppedCount += count
    }

    /// A file that stands in for one the user opened; `removeDemoFiles()` drops it.
    func addDemoFile(_ file: PeekSessionFile, entries: [PeekEntry]) {
        insertFile(file, entries: entries, atTop: false)
    }

    /// Newest last; a repeat of the same refusal replaces the older one.
    func addRejected(_ connection: PeekRejectedConnection) {
        rejected.removeAll {
            $0.address == connection.address && $0.name == connection.name && $0.reason == connection.reason
        }
        rejected.append(connection)
        if rejected.count > Self.rejectedLimit { rejected.removeFirst(rejected.count - Self.rejectedLimit) }
    }

    func upsert(_ entries: some Sequence<PeekEntry>, in id: PeekSessionID) {
        stores[id, default: SessionStore()].upsert(contentsOf: entries)
    }

    func completeBodyLoad(_ key: PeekBodyLoadKey, in id: PeekSessionID, with body: PeekBody) {
        bodyLoads[key] = nil
        stores[id]?.update(key.entryID) { entry in
            switch key.side {
            case .response:
                guard let response = entry.response else { return }
                entry.response = PeekResponse(
                    statusCode: response.statusCode,
                    statusMessage: response.statusMessage,
                    headers: response.headers,
                    body: body,
                    redirects: response.redirects
                )
            case .request:
                let request = entry.request
                entry = PeekEntry(
                    id: entry.id,
                    request: PeekRequest(method: request.method, uri: request.uri, headers: request.headers, body: body, extra: request.extra),
                    startedAt: entry.startedAt,
                    source: entry.source,
                    response: entry.response,
                    failure: entry.failure,
                    completedAt: entry.completedAt,
                    isPinned: entry.isPinned,
                    timings: entry.timings
                )
            }
        }
    }

    func failBodyLoad(_ key: PeekBodyLoadKey, message: String) {
        bodyLoads[key] = .failed(message)
    }

    private static let rejectedLimit = 20

    private func insertFile(_ file: PeekSessionFile, entries: [PeekEntry], atTop: Bool) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = file
        } else if atTop {
            files.insert(file, at: 0)
        } else {
            files.append(file)
        }
        stores[file.id] = SessionStore(entries: entries)
    }
}

extension PeekServerState {
    nonisolated static let defaultPort = 9741

    /// Three groups of four, without look-alike characters, so it can be read out and typed.
    nonisolated static func newToken() -> String {
        let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
        let groups = (0..<3).map { _ in String((0..<4).map { _ in alphabet.randomElement()! }) }
        return groups.joined(separator: "-")
    }

    static func launchToken(policy: TokenPolicy, stored: String?) -> String {
        if policy == .persistent, let stored, !stored.isEmpty { return stored }
        return newToken()
    }
}
