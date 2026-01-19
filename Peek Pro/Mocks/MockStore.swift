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
    private var entriesBySession: [PeekSessionID: [PeekEntry]] = [:]

    @ObservationIgnored private let isLive: Bool
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var pendingTemplates: [PeekId: PeekEntry] = [:]
    @ObservationIgnored private var tickCount = 0

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
    }

    func removeSession(_ id: PeekSessionID) {
        sessions.removeAll { $0.id == id }
        entriesBySession[id] = nil
    }

    func regenerateToken() {
        let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
        let groups = (0..<3).map { _ in String((0..<4).map { _ in alphabet.randomElement()! }) }
        server.token = groups.joined(separator: "-")
    }

    private func load(_ scenario: MockScenario) {
        ticker?.cancel()
        ticker = nil
        pendingTemplates = [:]
        server = FixtureSessions.server
        sessions = []
        files = []
        rejected = []
        paused = []
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
        case .rejected:
            rejected = FixtureSessions.rejected
        }

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
        loadFiles()
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
