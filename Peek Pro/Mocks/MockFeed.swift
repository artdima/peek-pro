import Foundation
import Observation

/// Fills a `SessionHub` with a mock scenario until real devices connect (Phase 5); screens never see it.
@Observable
final class MockFeed {
    private(set) var scenario: MockScenario
    @ObservationIgnored private let hub: SessionHub
    @ObservationIgnored private let isLive: Bool
    /// Off when the real server owns the hub's server state.
    @ObservationIgnored private let fakesServer: Bool
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var pendingTemplates: [PeekId: PeekEntry] = [:]
    @ObservationIgnored private var tickCount = 0
    @ObservationIgnored private var failedLoads: Set<PeekBodyLoadKey> = []
    /// What this feed put into the hub, so a scenario switch leaves real devices alone.
    @ObservationIgnored private var ownSessions: [PeekSessionID] = []

    init(hub: SessionHub, scenario: MockScenario = .live, isLive: Bool = true, fakesServer: Bool = true) {
        self.hub = hub
        self.scenario = scenario
        self.isLive = isLive
        self.fakesServer = fakesServer
        hub.bodyLoader = { [weak self] key, id in self?.loadBody(key, in: id) }
        load(scenario)
    }

    func select(_ scenario: MockScenario) {
        guard scenario != self.scenario else { return }
        self.scenario = scenario
        load(scenario)
    }

    func openDemoFiles() {
        hub.addDemoFiles()
    }

    /// Pretends to fetch a body from the device; the map tile fails once so Retry can be seen.
    private func loadBody(_ key: PeekBodyLoadKey, in sessionID: PeekSessionID) {
        guard ownSessions.contains(sessionID) || hub.file(sessionID) != nil else {
            hub.failBodyLoad(key, in: sessionID, message: "The device isn't connected.")
            return
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, self.hub.bodyLoad(key, in: sessionID) == .loading else { return }
            if key.entryID.value.hasSuffix("f25"), !self.failedLoads.contains(key) {
                self.failedLoads.insert(key)
                self.hub.failBodyLoad(key, in: sessionID, message: "The device didn't answer within 10 seconds.")
                return
            }
            guard key.side == .response,
                  case .remote(_, let type, _) = self.hub.entry(key.entryID, in: sessionID)?.response?.body
            else { return }
            let body: PeekBody = type?.isImage == true
                ? .bytes(FixtureBodies.avatarPNG, contentType: type)
                : .json(FixtureBodies.remoteConfig)
            self.hub.completeBodyLoad(key, in: sessionID, with: body)
        }
    }

    private func load(_ scenario: MockScenario) {
        ticker?.cancel()
        ticker = nil
        pendingTemplates = [:]
        failedLoads = []
        removeOwn()
        if fakesServer {
            hub.setServer(FixtureSessions.server)
            hub.applyServerSettings()
        }

        switch scenario {
        case .waiting:
            break
        case .portInUse:
            var server = hub.server
            server.status = .portInUse
            hub.setServer(server)
        case .live, .paused:
            add(FixtureSessions.iPhoneSession, entries: Fixtures.session)
            add(FixtureSessions.pixelSession, entries: FixtureSessions.pixelEntries)
            add(FixtureSessions.chromeSession)
            add(FixtureSessions.iPadSession, entries: FixtureSessions.iPadEntries)
            if scenario == .paused { hub.togglePaused(FixtureSessions.iPhoneSession.id) }
        case .large:
            add(FixtureSessions.iPhoneSession, entries: Fixtures.large)
        case .huge:
            add(FixtureSessions.iPhoneSession, entries: Fixtures.bulk(SessionStore.defaultLimit))
        case .disconnected:
            var iPhone = FixtureSessions.iPhoneSession
            iPhone.connection = .disconnected
            iPhone.disconnectedAt = Fixtures.start.addingTimeInterval(75)
            add(iPhone, entries: Fixtures.session)
            add(FixtureSessions.iPadSession, entries: FixtureSessions.iPadEntries)
        case .file:
            openDemoFiles()
            hub.addDemoFile(FixtureSessions.futureFile, entries: FixtureSessions.futureFileEntries)
            hub.addDemoFile(FixtureSessions.legacyFile, entries: [])
        case .rejected:
            FixtureSessions.rejected.forEach(hub.addRejected)
        }

        if isLive && (scenario == .live || scenario == .huge) { startTicking() }
    }

    private func add(_ session: PeekLiveSession, entries: [PeekEntry] = []) {
        hub.addSession(session, entries: entries)
        ownSessions.append(session.id)
    }

    private func removeOwn() {
        ownSessions.forEach(hub.removeSession)
        ownSessions = []
        for connection in FixtureSessions.rejected { hub.dismissRejected(connection.id) }
        hub.removeDemoFiles()
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
        guard hub.session(target) != nil, !hub.isPaused(target) else { return }
        var finished: [PeekEntry] = []
        for (id, template) in pendingTemplates {
            guard let entry = hub.entry(id, in: target) else { continue }
            finished.append(entry.finished(like: template))
            pendingTemplates[id] = nil
        }
        let templates = Fixtures.liveTemplates
        let template = templates[tickCount % templates.count]
        tickCount += 1
        let id = PeekId("live-\(tickCount)")
        pendingTemplates[id] = template
        hub.upsert(finished + [template.restarted(id: id, at: .now)], in: target)
    }
}
