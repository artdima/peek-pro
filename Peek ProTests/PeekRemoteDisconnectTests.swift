import Foundation
import Testing
@testable import Peek_Pro

@MainActor
@Suite("Remote disconnects")
struct PeekRemoteDisconnectTests {
    private let hub = SessionHub(server: PeekServerState(
        status: .listening,
        port: 9741,
        addresses: [],
        bonjourName: nil,
        token: "k7q4-mx2p-9vd3"
    ))
    private let id = PeekSessionID.live("3f2a")

    private func hello(_ session: String = "3f2a") -> PeekRemoteFrame {
        .hello(PeekRemoteHello(
            protocolVersion: PeekRemoteProtocol.version,
            token: "k7q4-mx2p-9vd3",
            sessionID: session,
            info: PeekSessionInfo(name: "Acme Shop", platform: .iOS, osVersion: "26.0", peekVersion: "1.4.0", startedAt: .now)
        ))
    }

    private func connect(_ remote: PeekRemoteSessions, session: String = "3f2a", answersPing: Bool = false) -> FakeChannel {
        let channel = FakeChannel()
        channel.answersPing = answersPing
        remote.accept(channel)
        channel.receive(hello(session))
        for entry in Fixtures.session.prefix(3) { channel.receive(.entryAdded(entry)) }
        channel.receive(.synced(count: 3))
        return channel
    }

    @Test("keeps a session the device left readable and savable")
    func keepsSession() throws {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        let channel = connect(remote)
        channel.close()

        #expect(hub.session(id)?.connection == .disconnected)
        #expect(hub.entries(in: id).count == 3)
        let info = try #require(hub.info(for: id))
        let data = PeekFileWriter.data(info: info, entries: hub.entries(in: id))
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
        #expect(lines.count == 4)
    }

    @Test("closes a device disconnected here and turns it away when it comes back")
    func disconnectHere() throws {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        let channel = connect(remote)
        #expect(remote.disconnect(id))
        #expect(channel.isClosed)
        #expect(hub.session(id)?.connection == .disconnected)
        #expect(hub.entries(in: id).count == 3)

        let again = FakeChannel()
        remote.accept(again)
        again.receive(hello())
        guard case .denied(.other, _)? = again.sent.first else {
            Issue.record("Expected a denial, got \(again.sent)")
            return
        }
        #expect(again.isClosed)
        #expect(hub.rejected.isEmpty)

        // The app restarted: a new session id is welcome.
        let restarted = FakeChannel()
        remote.accept(restarted)
        restarted.receive(hello("new"))
        #expect(!restarted.isClosed)
    }

    @Test("has nothing to disconnect for a session it doesn't hold")
    func nothingToDisconnect() {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        #expect(!remote.disconnect(.live("iphone")))
        let channel = connect(remote)
        channel.close()
        #expect(!remote.disconnect(id))
    }

    /// Polls: the heartbeat runs on the main actor alongside the other tests.
    private func eventually(_ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition() {
            if ContinuousClock.now >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return true
    }

    @Test("pings a quiet device and drops one that doesn't answer")
    func dropsSilent() async {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        remote.heartbeatInterval = .milliseconds(50)
        remote.answerLimit = .milliseconds(100)
        let silent = connect(remote)
        let alive = connect(remote, session: "alive", answersPing: true)

        #expect(await eventually { silent.isClosed })
        #expect(silent.sent.contains(.ping))
        #expect(hub.session(id)?.connection == .disconnected)
        #expect(await eventually { alive.sent.contains(.ping) })
        #expect(!alive.isClosed)
        #expect(hub.session(.live("alive"))?.connection == .connected)
        alive.close()
    }

    @Test("counts any frame as an answer")
    func anyFrameCounts() async {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        remote.heartbeatInterval = .milliseconds(50)
        remote.answerLimit = .seconds(1)
        let channel = connect(remote)
        for index in 0..<10 {
            try? await Task.sleep(for: .milliseconds(50))
            channel.receive(.entryAdded(Fixtures.entry("f0\(index % 9 + 1)")))
        }
        #expect(!channel.isClosed)
        channel.close()
    }
}
