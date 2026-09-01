import Foundation
import Testing
@testable import Peek_Pro

@MainActor
@Suite("Remote entry stream")
struct PeekRemoteStreamTests {
    private let hub = SessionHub(server: PeekServerState(
        status: .listening,
        port: 9741,
        addresses: [],
        bonjourName: nil,
        token: "k7q4-mx2p-9vd3"
    ))
    private let id = PeekSessionID.live("3f2a")

    private var hello: PeekRemoteFrame {
        .hello(PeekRemoteHello(
            protocolVersion: PeekRemoteProtocol.version,
            token: "k7q4-mx2p-9vd3",
            sessionID: "3f2a",
            info: PeekSessionInfo(name: "Acme Shop", platform: .iOS, osVersion: "26.0", peekVersion: "1.4.0", startedAt: .now)
        ))
    }

    /// Welcomed, with the history already over unless asked otherwise.
    private func connect(_ remote: PeekRemoteSessions, history: [PeekEntry] = [], synced: Bool = true) -> FakeChannel {
        let channel = FakeChannel()
        remote.accept(channel)
        channel.receive(hello)
        for entry in history { channel.receive(.entryAdded(entry)) }
        if synced { channel.receive(.synced(count: history.count)) }
        return channel
    }

    private func ids() -> [String] {
        hub.entries(in: id).map(\.id.value)
    }

    @Test("shows the history only once it's complete")
    func historyInOneGo() {
        let remote = PeekRemoteSessions(hub: hub)
        let history = Array(Fixtures.session.prefix(5))
        let channel = connect(remote, history: history, synced: false)
        #expect(hub.entries(in: id).isEmpty)

        let revision = hub.store(id)?.revision
        channel.receive(.synced(count: 5))
        #expect(ids() == history.map(\.id.value))
        #expect(hub.store(id)?.revision != revision)
    }

    @Test("reads a whole spec session sent frame by frame")
    func specSession() throws {
        let loaded = try PeekFileLoader.load(try Spec.url("basic.peek"))
        let remote = PeekRemoteSessions(hub: hub)
        // Through text, as the socket would carry it.
        let channel = FakeChannel()
        remote.accept(channel)
        channel.receive(hello)
        for entry in loaded.entries { channel.receive(text: PeekRemoteFrame.entryAdded(entry).text) }
        channel.receive(text: PeekRemoteFrame.synced(count: loaded.entries.count).text)
        #expect(hub.entries(in: id) == loaded.entries)
    }

    @Test("applies updates, removals and clears inside the history")
    func historyChanges() {
        let remote = PeekRemoteSessions(hub: hub)
        let a = Fixtures.entry("f01"), b = Fixtures.entry("f02"), c = Fixtures.entry("f03")
        let channel = connect(remote, history: [a, b], synced: false)
        channel.receive(.cleared)
        channel.receive(.entryAdded(c))
        channel.receive(.entryUpdated(a))
        channel.receive(.entryAdded(b))
        channel.receive(.entryRemoved(b.id))
        channel.receive(.synced(count: 3))
        #expect(ids() == ["f03", "f01"])
    }

    @Test("streams live changes after the history")
    func live() {
        let remote = PeekRemoteSessions(hub: hub)
        let template = Fixtures.entry("f02")
        let pending = template.restarted(id: PeekId("n1"), at: .now)
        let channel = connect(remote, history: [Fixtures.entry("f01")])

        channel.receive(.entryAdded(pending))
        #expect(ids() == ["f01", "n1"])
        #expect(hub.entry(PeekId("n1"), in: id)?.state == .pending)

        channel.receive(.entryUpdated(pending.finished(like: template)))
        #expect(ids() == ["f01", "n1"])
        #expect(hub.entry(PeekId("n1"), in: id)?.state != .pending)

        channel.receive(.entryRemoved(PeekId("f01")))
        #expect(ids() == ["n1"])
        channel.receive(.cleared)
        #expect(ids().isEmpty)
    }

    @Test("treats add for a held id as update, and update for an unknown id as add")
    func lenientOps() {
        let remote = PeekRemoteSessions(hub: hub)
        let template = Fixtures.entry("f02")
        let pending = template.restarted(id: PeekId("n1"), at: .now)
        let channel = connect(remote, history: [pending])
        channel.receive(.entryAdded(pending.finished(like: template)))
        #expect(ids() == ["n1"])
        #expect(hub.entry(PeekId("n1"), in: id)?.state != .pending)
        channel.receive(.entryUpdated(Fixtures.entry("f03")))
        #expect(ids() == ["n1", "f03"])
    }

    @Test("keeps new calls out while paused, but lets shown ones finish")
    func paused() {
        let remote = PeekRemoteSessions(hub: hub)
        let template = Fixtures.entry("f02")
        let pending = template.restarted(id: PeekId("n1"), at: .now)
        let channel = connect(remote, history: [pending])
        hub.togglePaused(id)
        channel.receive(.entryAdded(Fixtures.entry("f03")))
        channel.receive(.entryUpdated(pending.finished(like: template)))
        #expect(ids() == ["n1"])
        #expect(hub.entry(PeekId("n1"), in: id)?.state != .pending)
    }

    @Test("adds up dropped frames")
    func dropped() {
        let remote = PeekRemoteSessions(hub: hub)
        let channel = connect(remote)
        channel.receive(.dropped(count: 3))
        channel.receive(.dropped(count: 4))
        #expect(hub.session(id)?.droppedCount == 7)
    }

    @Test("answers ping with pong, in the history too")
    func ping() {
        let remote = PeekRemoteSessions(hub: hub)
        let channel = connect(remote, synced: false)
        channel.receive(.ping)
        channel.receive(.synced(count: 0))
        channel.receive(.ping)
        #expect(channel.sent.dropFirst() == [.pong, .pong])
    }

    @Test("keeps what it showed until the reconnected app's history is complete")
    func reconnect() {
        let remote = PeekRemoteSessions(hub: hub)
        let first = connect(remote, history: [Fixtures.entry("f01"), Fixtures.entry("f02")])
        hub.setPinned([PeekId("f01")], to: true, in: id)
        channel(first, drops: 2)
        first.close()

        let again = connect(remote, history: [Fixtures.entry("f01"), Fixtures.entry("f03")], synced: false)
        #expect(ids() == ["f01", "f02"])
        #expect(hub.session(id)?.connection == .connected)
        again.receive(.synced(count: 2))
        #expect(ids() == ["f01", "f03"])
        #expect(hub.entry(PeekId("f01"), in: id)?.isPinned == true)
        #expect(hub.session(id)?.droppedCount == 2)
    }

    @Test("forgets a history cut short by a disconnect")
    func cutShort() {
        let remote = PeekRemoteSessions(hub: hub)
        let channel = connect(remote, history: [Fixtures.entry("f01")], synced: false)
        channel.close()
        channel.receive(.synced(count: 1))
        #expect(hub.entries(in: id).isEmpty)
        #expect(hub.session(id)?.connection == .disconnected)
    }

    private func channel(_ channel: FakeChannel, drops count: Int) {
        channel.receive(.dropped(count: count))
    }
}
