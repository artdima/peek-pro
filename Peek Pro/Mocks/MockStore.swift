import Foundation
import Observation

/// Stands in for the session store until the real one arrives in Phase 3; screens only see this API.
@Observable
final class MockStore {
    private(set) var scenario: MockScenario
    private(set) var server = FixtureSessions.server
    private(set) var sessions: [PeekLiveSession] = []
    private(set) var files: [PeekSessionFile] = []
    private(set) var rejected: [PeekRejectedConnection] = []
    private(set) var paused: Set<PeekSessionID> = []
    private(set) var bodyLoads: [PeekBodyLoadKey: PeekBodyLoadState] = [:]
    private var entriesBySession: [PeekSessionID: [PeekEntry]] = [:]
    @ObservationIgnored private var openedFileIDs: Set<PeekSessionID> = []

    @ObservationIgnored private let isLive: Bool
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var pendingTemplates: [PeekId: PeekEntry] = [:]
    @ObservationIgnored private var tickCount = 0
    @ObservationIgnored private var failedLoads: Set<PeekBodyLoadKey> = []

    init(scenario: MockScenario = .live, isLive: Bool = true) {
        self.scenario = scenario
        self.isLive = isLive
        load(scenario)
    }

    func select(_ scenario: MockScenario) {
        guard scenario != self.scenario else { return }
        self.scenario = scenario
        load(scenario)
    }

    var sessionIDs: [PeekSessionID] {
        sessions.map(\.id) + files.map(\.id)
    }

    func entries(in id: PeekSessionID) -> [PeekEntry] {
        entriesBySession[id] ?? []
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

    func togglePaused(_ id: PeekSessionID) {
        if paused.contains(id) { paused.remove(id) } else { paused.insert(id) }
    }

    func clear(_ id: PeekSessionID) {
        entriesBySession[id] = []
    }

    func togglePin(_ entryID: PeekId, in id: PeekSessionID) {
        guard let index = entriesBySession[id]?.firstIndex(where: { $0.id == entryID }) else { return }
        entriesBySession[id]?[index].isPinned.toggle()
    }

    func closeFile(_ id: PeekSessionID) {
        files.removeAll { $0.id == id }
        entriesBySession[id] = nil
        openedFileIDs.remove(id)
    }

    func removeSession(_ id: PeekSessionID) {
        sessions.removeAll { $0.id == id }
        entriesBySession[id] = nil
    }

    func disconnect(_ id: PeekSessionID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].connection = .disconnected
        sessions[index].disconnectedAt = .now
    }

    func dismissRejected(_ id: String) {
        rejected.removeAll { $0.id == id }
    }

    /// The demo files behind "Open Demo Session".
    func openDemoFiles() {
        loadFiles()
    }

    /// A file opened for real; opening the same file again replaces it. It outlives scenario switches.
    func addFile(_ file: PeekSessionFile, entries: [PeekEntry], atTop: Bool = true) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = file
        } else if atTop {
            files.insert(file, at: 0)
        } else {
            files.append(file)
        }
        entriesBySession[file.id] = entries
        openedFileIDs.insert(file.id)
    }

    /// Pretends to fetch a body from the device; the map tile fails once so Retry can be seen.
    func loadBody(_ key: PeekBodyLoadKey, in sessionID: PeekSessionID) {
        guard bodyLoads[key] != .loading else { return }
        bodyLoads[key] = .loading
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, self.bodyLoads[key] == .loading else { return }
            if key.entryID.value.hasSuffix("f25"), !self.failedLoads.contains(key) {
                self.failedLoads.insert(key)
                self.bodyLoads[key] = .failed("The device didn't answer within 10 seconds.")
                return
            }
            self.bodyLoads[key] = nil
            self.fillBody(key, in: sessionID)
        }
    }

    private func fillBody(_ key: PeekBodyLoadKey, in sessionID: PeekSessionID) {
        guard key.side == .response,
              let index = entriesBySession[sessionID]?.firstIndex(where: { $0.id == key.entryID }),
              let entry = entriesBySession[sessionID]?[index],
              let response = entry.response,
              case .remote(_, let type, _) = response.body
        else { return }
        let body: PeekBody = type?.isImage == true
            ? .bytes(FixtureBodies.avatarPNG, contentType: type)
            : .json(FixtureBodies.remoteConfig)
        entriesBySession[sessionID]?[index].response = PeekResponse(
            statusCode: response.statusCode,
            statusMessage: response.statusMessage,
            headers: response.headers,
            body: body,
            redirects: response.redirects
        )
    }

    /// The fixture server with the port and Bonjour name from Settings.
    private static func configuredServer() -> PeekServerState {
        var server = FixtureSessions.server
        let defaults = UserDefaults.standard
        let port = defaults.integer(forKey: SettingsKey.port)
        if port > 0 { server.port = port }
        if defaults.object(forKey: SettingsKey.bonjourEnabled) as? Bool == false {
            server.bonjourName = nil
        } else if let name = defaults.string(forKey: SettingsKey.bonjourName), !name.isEmpty {
            server.bonjourName = name
        }
        return server
    }

    func applyServerSettings() {
        let configured = Self.configuredServer()
        server.port = configured.port
        server.bonjourName = configured.bonjourName
    }

    func regenerateToken() {
        let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
        let groups = (0..<3).map { _ in String((0..<4).map { _ in alphabet.randomElement()! }) }
        server.token = groups.joined(separator: "-")
    }

    private func load(_ scenario: MockScenario) {
        let opened = files.filter { openedFileIDs.contains($0.id) }
        let openedEntries = opened.map { entriesBySession[$0.id] ?? [] }
        ticker?.cancel()
        ticker = nil
        pendingTemplates = [:]
        server = Self.configuredServer()
        sessions = []
        files = []
        rejected = []
        paused = []
        bodyLoads = [:]
        failedLoads = []
        entriesBySession = [:]

        switch scenario {
        case .waiting:
            break
        case .portInUse:
            server.status = .portInUse
        case .live, .paused:
            loadEverything()
            if scenario == .paused { paused = [FixtureSessions.iPhoneSession.id] }
        case .large:
            sessions = [FixtureSessions.iPhoneSession]
            entriesBySession[FixtureSessions.iPhoneSession.id] = Fixtures.large
        case .disconnected:
            var iPhone = FixtureSessions.iPhoneSession
            iPhone.connection = .disconnected
            iPhone.disconnectedAt = Fixtures.start.addingTimeInterval(75)
            sessions = [iPhone, FixtureSessions.iPadSession]
            entriesBySession[iPhone.id] = Fixtures.session
            entriesBySession[FixtureSessions.iPadSession.id] = FixtureSessions.iPadEntries
        case .file:
            loadFiles()
            files += [FixtureSessions.futureFile, FixtureSessions.legacyFile]
            entriesBySession[FixtureSessions.futureFile.id] = FixtureSessions.futureFileEntries
        case .rejected:
            rejected = FixtureSessions.rejected
        }

        files = opened + files.filter { !openedFileIDs.contains($0.id) }
        for (file, entries) in zip(opened, openedEntries) { entriesBySession[file.id] = entries }

        if isLive && scenario == .live { startTicking() }
    }

    private func loadEverything() {
        sessions = [
            FixtureSessions.iPhoneSession,
            FixtureSessions.pixelSession,
            FixtureSessions.chromeSession,
            FixtureSessions.iPadSession,
        ]
        entriesBySession[FixtureSessions.iPhoneSession.id] = Fixtures.session
        entriesBySession[FixtureSessions.pixelSession.id] = FixtureSessions.pixelEntries
        entriesBySession[FixtureSessions.iPadSession.id] = FixtureSessions.iPadEntries
    }

    private func loadFiles() {
        files = [FixtureSessions.savedSession, FixtureSessions.bugReport]
        entriesBySession[FixtureSessions.savedSession.id] = Fixtures.copies(of: Fixtures.session, prefix: "saved", shiftedBy: -73_000)
        entriesBySession[FixtureSessions.bugReport.id] = FixtureSessions.bugReportEntries
    }

    private func startTicking() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled, let self else { return }
                self.tick()
            }
        }
    }

    /// Finishes the calls started on the previous tick and starts a new one.
    private func tick() {
        let target = FixtureSessions.iPhoneSession.id
        guard !paused.contains(target), var entries = entriesBySession[target] else { return }
        for index in entries.indices {
            let entry = entries[index]
            guard let template = pendingTemplates.removeValue(forKey: entry.id) else { continue }
            entries[index] = entry.finished(like: template)
        }
        let templates = Fixtures.liveTemplates
        let template = templates[tickCount % templates.count]
        tickCount += 1
        let id = PeekId("live-\(tickCount)")
        pendingTemplates[id] = template
        entries.append(template.restarted(id: id, at: .now))
        entriesBySession[target] = entries
    }
}
