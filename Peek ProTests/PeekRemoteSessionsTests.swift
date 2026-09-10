import Foundation
import Testing
@testable import Peek_Pro

/// A connection without a socket: what the desktop sends is read back as frames.
@MainActor
final class FakeChannel: PeekRemoteChannel {
    let address: String
    var onText: ((String) -> Void)?
    var onClose: (() -> Void)?
    private(set) var sent: [PeekRemoteFrame] = []
    private(set) var isClosed = false

    init(address: String = "192.168.1.20") {
        self.address = address
    }

    /// Answers `ping` the way `PeekRemote` does.
    var answersPing = false

    func send(_ text: String) {
        guard !isClosed else { return }
        let frame = (try? PeekRemoteFrame(text: text)) ?? .unknown(type: text)
        sent.append(frame)
        if answersPing, frame == .ping { onText?(PeekRemoteFrame.pong.text) }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        let onClose = onClose
        self.onClose = nil
        onClose?()
    }

    func receive(_ frame: PeekRemoteFrame) {
        onText?(frame.text)
    }

    func receive(text: String) {
        onText?(text)
    }
}

@MainActor
@Suite("Remote handshake and sessions")
struct PeekRemoteSessionsTests {
    private let hub = SessionHub(server: PeekServerState(
        status: .listening,
        port: 9741,
        addresses: [],
        bonjourName: nil,
        token: "k7q4-mx2p-9vd3"
    ))

    private func sessions() -> PeekRemoteSessions {
        PeekRemoteSessions(hub: hub, serverVersion: "1.0")
    }

    private func hello(
        _ sessionID: String = "3f2a",
        token: String? = "k7q4-mx2p-9vd3",
        version: Int = PeekRemoteProtocol.version,
        name: String? = "Acme Shop",
        platform: PeekPlatform = .iOS
    ) -> PeekRemoteFrame {
        .hello(PeekRemoteHello(
            protocolVersion: version,
            token: token,
            sessionID: sessionID,
            info: PeekSessionInfo(
                name: name,
                platform: platform,
                osVersion: "26.0",
                peekVersion: "1.4.0",
                startedAt: Date(timeIntervalSince1970: 1_790_000_000)
            )
        ))
    }

    @Test("welcomes an app with the right token and opens its session")
    func welcomes() throws {
        let remote = sessions()
        var opened: [PeekSessionID] = []
        remote.onOpen = { opened.append($0) }
        let channel = FakeChannel()
        remote.accept(channel)
        channel.receive(hello())

        #expect(channel.sent == [.welcome(serverName: "Peek Pro", serverVersion: "1.0")])
        #expect(!channel.isClosed)
        let session = try #require(hub.sessions.first)
        #expect(hub.sessions.count == 1)
        #expect(session.id == .live("3f2a"))
        #expect(session.info.name == "Acme Shop")
        #expect(session.info.platform == .iOS)
        #expect(session.info.peekVersion == "1.4.0")
        #expect(session.address == "192.168.1.20")
        #expect(session.connection == .connected)
        #expect(hub.entries(in: session.id).isEmpty)
        #expect(opened == [.live("3f2a")])
        #expect(remote.connectedCount == 1)
    }

    @Test("turns away a wrong or missing token and lists the attempt")
    func wrongToken() throws {
        let remote = sessions()
        for token in ["nope", nil] {
            let channel = FakeChannel()
            remote.accept(channel)
            channel.receive(hello(token: token))
            guard case .denied(.token, _)? = channel.sent.first else {
                Issue.record("Expected a token denial, got \(channel.sent)")
                return
            }
            #expect(channel.sent.count == 1)
            #expect(channel.isClosed)
        }
        #expect(hub.sessions.isEmpty)
        let rejected = try #require(hub.rejected.first)
        #expect(hub.rejected.count == 1)
        #expect(rejected.reason == .invalidToken)
        #expect(rejected.address == "192.168.1.20")
        #expect(rejected.name == "Acme Shop")
        #expect(rejected.platform == .iOS)
    }

    @Test("turns away a protocol it doesn't speak, before looking at the token")
    func wrongVersion() throws {
        let remote = sessions()
        let channel = FakeChannel()
        remote.accept(channel)
        channel.receive(hello(token: "nope", version: PeekRemoteProtocol.version + 1))
        guard case .denied(.protocolVersion, _)? = channel.sent.first else {
            Issue.record("Expected a version denial, got \(channel.sent)")
            return
        }
        #expect(channel.isClosed)
        #expect(hub.rejected.map(\.reason) == [.unsupportedProtocol(version: PeekRemoteProtocol.version + 1)])
    }

    @Test("ignores what comes before hello, and a second hello")
    func ignoresOtherFrames() {
        let remote = sessions()
        let channel = FakeChannel()
        remote.accept(channel)
        channel.receive(.ping)
        channel.receive(text: "not json")
        channel.receive(.synced(count: 3))
        #expect(channel.sent.isEmpty)
        #expect(hub.sessions.isEmpty)

        channel.receive(hello())
        channel.receive(hello("other"))
        #expect(channel.sent.count == 1)
        #expect(hub.sessions.map(\.id) == [.live("3f2a")])
    }

    @Test("keeps several devices at once")
    func severalDevices() {
        let remote = sessions()
        let phone = FakeChannel(address: "192.168.1.20")
        let tablet = FakeChannel(address: "192.168.1.21")
        remote.accept(phone)
        remote.accept(tablet)
        phone.receive(hello("a"))
        tablet.receive(hello("b", name: nil, platform: .android))
        #expect(hub.sessions.map(\.id) == [.live("a"), .live("b")])
        #expect(hub.sessions.map(\.address) == ["192.168.1.20", "192.168.1.21"])
        #expect(remote.connectedCount == 2)
    }

    @Test("marks the session disconnected when the device goes")
    func disconnects() {
        let remote = sessions()
        let channel = FakeChannel()
        remote.accept(channel)
        channel.receive(hello())
        channel.close()
        #expect(hub.sessions.first?.connection == .disconnected)
        #expect(hub.sessions.first?.disconnectedAt != nil)
        #expect(remote.connectedCount == 0)
    }

    @Test("takes an app back into its own session, in the same place")
    func reconnects() {
        let remote = sessions()
        let first = FakeChannel()
        let other = FakeChannel(address: "192.168.1.21")
        remote.accept(first)
        remote.accept(other)
        first.receive(hello("a"))
        other.receive(hello("b"))
        first.close()

        let again = FakeChannel(address: "192.168.1.30")
        remote.accept(again)
        again.receive(hello("a"))
        #expect(hub.sessions.map(\.id) == [.live("a"), .live("b")])
        #expect(hub.sessions.first?.connection == .connected)
        #expect(hub.sessions.first?.address == "192.168.1.30")
    }

    @Test("closes the old socket when the app is back before it noticed")
    func replacesStaleConnection() {
        let remote = sessions()
        let stale = FakeChannel()
        remote.accept(stale)
        stale.receive(hello())
        let fresh = FakeChannel()
        remote.accept(fresh)
        fresh.receive(hello())

        #expect(stale.isClosed)
        #expect(hub.sessions.count == 1)
        #expect(hub.sessions.first?.connection == .connected)
        #expect(remote.connectedCount == 1)
    }

    @Test("closes a connection that never says hello")
    func helloTimeout() async {
        let remote = sessions()
        remote.helloTimeout = .milliseconds(30)
        let silent = FakeChannel()
        let polite = FakeChannel()
        remote.accept(silent)
        remote.accept(polite)
        polite.receive(hello())
        try? await Task.sleep(for: .milliseconds(200))
        #expect(silent.isClosed)
        #expect(!polite.isClosed)
    }

    @Test("checks against the token shown now")
    func newToken() {
        let remote = sessions()
        // Not regenerateToken(): that writes the app's own defaults.
        var server = hub.server
        server.token = "zzzz-zzzz-zzzz"
        hub.setServer(server)
        let channel = FakeChannel()
        remote.accept(channel)
        channel.receive(hello())
        #expect(channel.isClosed)
        let fresh = FakeChannel()
        remote.accept(fresh)
        fresh.receive(hello(token: hub.server.token))
        #expect(!fresh.isClosed)
    }
}

@MainActor
@Suite("Rejected connections")
struct RejectedConnectionsTests {
    private func rejection(_ address: String, _ reason: PeekRejectedConnection.Reason = .invalidToken) -> PeekRejectedConnection {
        PeekRejectedConnection(id: UUID().uuidString, address: address, name: "Acme", platform: .iOS, reason: reason, at: .now)
    }

    @Test("replaces a repeat and keeps the newest last")
    func repeats() {
        let hub = SessionHub()
        hub.addRejected(rejection("10.0.0.1"))
        hub.addRejected(rejection("10.0.0.2"))
        hub.addRejected(rejection("10.0.0.1"))
        #expect(hub.rejected.map(\.address) == ["10.0.0.2", "10.0.0.1"])
        hub.addRejected(rejection("10.0.0.2", .unsupportedProtocol(version: 2)))
        #expect(hub.rejected.count == 3)
    }

    @Test("keeps only the latest twenty")
    func limit() {
        let hub = SessionHub()
        for index in 0..<25 { hub.addRejected(rejection("10.0.0.\(index)")) }
        #expect(hub.rejected.count == 20)
        #expect(hub.rejected.first?.address == "10.0.0.5")
    }
}

@MainActor
@Suite("Mock feed beside real devices")
struct MockFeedIsolationTests {
    @Test("switching scenarios leaves real sessions and refusals alone")
    func leavesRealDevices() {
        let hub = SessionHub()
        let feed = MockFeed(hub: hub, scenario: .live, isLive: false, fakesServer: false)
        let real = PeekLiveSession(
            key: "real",
            info: PeekSessionInfo(name: "Real", platform: .iOS, osVersion: nil, peekVersion: "1.4.0", startedAt: .now),
            connection: .connected,
            address: "192.168.1.20",
            connectedAt: .now,
            droppedCount: 0
        )
        hub.addSession(real)
        hub.addRejected(PeekRejectedConnection(id: "x", address: "10.0.0.9", name: nil, platform: nil, reason: .invalidToken, at: .now))
        feed.select(.rejected)
        feed.select(.waiting)
        #expect(hub.sessions.map(\.id) == [real.id])
        #expect(hub.rejected.map(\.id) == ["x"])
    }
}
