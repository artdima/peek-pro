import Foundation
import Testing
@testable import Peek_Pro

@MainActor
@Suite("Pairing with a code")
struct PeekRemotePairingTests {
    private let hub = SessionHub(server: PeekServerState(
        status: .listening,
        port: 9741,
        addresses: [],
        bonjourName: nil,
        token: "k7q4-mx2p-9vd3"
    ))

    private func sessions(store: PeekPairedDevices = InMemoryPairedDevices()) -> PeekRemoteSessions {
        PeekRemoteSessions(hub: hub, serverVersion: "1.0", serverID: "mac-1", pairedDevices: store)
    }

    private func hello(_ sessionID: String = "3f2a", token: String? = nil, code: String? = nil) -> PeekRemoteFrame {
        .hello(PeekRemoteHello(
            token: token,
            code: code,
            sessionID: sessionID,
            info: PeekSessionInfo(name: "Acme Shop", platform: .iOS, osVersion: "26.0", peekVersion: "2.0.0", startedAt: .now)
        ))
    }

    private func connect(_ remote: PeekRemoteSessions, _ frame: PeekRemoteFrame, address: String = "192.168.1.20") -> FakeChannel {
        let channel = FakeChannel(address: address)
        remote.accept(channel)
        channel.receive(frame)
        return channel
    }

    /// A code that is not the one shown.
    private var wrongCode: String {
        hub.server.pairingCode.digits == "0000" ? "0001" : "0000"
    }

    private func issuedToken(_ channel: FakeChannel) -> String? {
        if case .welcome(_, _, _, _, let token)? = channel.sent.first { return token }
        return nil
    }

    @Test("makes four digits that run out")
    func code() {
        let code = PeekPairingCode.random(lifetime: 60, now: Date(timeIntervalSince1970: 1_790_000_000))
        #expect(code.digits.count == 4)
        #expect(code.digits.allSatisfy { $0.isNumber })
        #expect(code.expiresAt == Date(timeIntervalSince1970: 1_790_000_060))
        #expect(!code.isExpired(at: Date(timeIntervalSince1970: 1_790_000_059)))
        #expect(code.isExpired(at: Date(timeIntervalSince1970: 1_790_000_060)))
        #expect(PeekPairingCode(digits: "4719", issuedAt: .now, expiresAt: .now).spaced == "4 7 1 9")
    }

    @Test("answers the right code with a token, lists the device and shows a new code")
    func pairs() throws {
        let remote = sessions()
        let shown = hub.server.pairingCode
        let channel = connect(remote, hello(code: shown.digits))

        guard case .welcome(_, "Peek Pro", "1.0", "mac-1", let token?)? = channel.sent.first else {
            Issue.record("Expected a welcome with a token, got \(channel.sent)")
            return
        }
        #expect(token.count == 64)
        #expect(!channel.isClosed)
        #expect(hub.sessions.map(\.id) == [.live("3f2a")])
        let device = try #require(hub.pairedDevices.first)
        #expect(hub.pairedDevices.count == 1)
        #expect(device.name == "Acme Shop")
        #expect(device.platform == .iOS)
        #expect(device.address == "192.168.1.20")
        #expect(remote.pairedDevices.tokens[token] == device.id)
        #expect(remote.pairedDevices.devices == [device])
        #expect(hub.server.pairingCode != shown)
        #expect(hub.rejected.isEmpty)
    }

    @Test("takes the token it issued on later connections, without issuing another")
    func tokenAfterwards() throws {
        let remote = sessions()
        let first = connect(remote, hello(code: hub.server.pairingCode.digits))
        let token = try #require(issuedToken(first))
        first.close()

        let again = connect(remote, hello("new-run", token: token), address: "192.168.1.30")
        #expect(again.sent.first == .welcome(serverName: "Peek Pro", serverVersion: "1.0", serverID: "mac-1"))
        #expect(!again.isClosed)
        #expect(hub.pairedDevices.count == 1)
        #expect(hub.pairedDevices.first?.address == "192.168.1.30")
    }

    @Test("turns a wrong code away and says so in the sidebar")
    func wrong() {
        let remote = sessions()
        let shown = hub.server.pairingCode
        let channel = connect(remote, hello(code: wrongCode))
        guard case .denied(.code, _)? = channel.sent.first else {
            Issue.record("Expected a code denial, got \(channel.sent)")
            return
        }
        #expect(channel.isClosed)
        #expect(hub.rejected.map(\.reason) == [.wrongCode])
        #expect(hub.rejected.first?.name == "Acme Shop")
        #expect(hub.pairedDevices.isEmpty)
        #expect(hub.server.pairingCode == shown)
    }

    @Test("changes the code after five wrong tries, and counts afresh")
    func failures() {
        let remote = sessions()
        var shown = hub.server.pairingCode
        for _ in 0..<4 { _ = connect(remote, hello(code: wrongCode)) }
        #expect(hub.server.pairingCode == shown)
        _ = connect(remote, hello(code: wrongCode))
        #expect(hub.server.pairingCode != shown)

        shown = hub.server.pairingCode
        for _ in 0..<4 { _ = connect(remote, hello(code: wrongCode)) }
        #expect(hub.server.pairingCode == shown)
    }

    @Test("refuses a code that ran out, and shows a new one by itself")
    func expiry() async {
        let remote = sessions()
        remote.codeLifetime = 0.05
        let shown = hub.server.pairingCode
        try? await Task.sleep(for: .milliseconds(150))
        #expect(hub.server.pairingCode != shown)
        let channel = connect(remote, hello(code: shown.digits))
        guard case .denied(.code, _)? = channel.sent.first else {
            Issue.record("An old code was accepted")
            return
        }
    }

    @Test("still takes the token from Settings, without pairing")
    func settingsToken() {
        let remote = sessions()
        let channel = connect(remote, hello(token: "k7q4-mx2p-9vd3"))
        #expect(channel.sent.first == .welcome(serverName: "Peek Pro", serverVersion: "1.0", serverID: "mac-1"))
        #expect(hub.pairedDevices.isEmpty)
        let wrong = connect(remote, hello("other", token: "nope"))
        guard case .denied(.token, _)? = wrong.sent.first else {
            Issue.record("A wrong token was welcomed")
            return
        }
        #expect(hub.rejected.map(\.reason) == [.invalidToken])
    }

    @Test("a forgotten device is closed and asked for a code again")
    func forget() throws {
        let remote = sessions()
        let channel = connect(remote, hello(code: hub.server.pairingCode.digits))
        let token = try #require(issuedToken(channel))
        let device = try #require(hub.pairedDevices.first)

        remote.forgetDevice(device.id)
        #expect(channel.isClosed)
        #expect(hub.pairedDevices.isEmpty)
        #expect(remote.pairedDevices.tokens.isEmpty)
        #expect(remote.pairedDevices.devices.isEmpty)
        #expect(hub.session(.live("3f2a"))?.connection == .disconnected)

        let back = connect(remote, hello(token: token))
        guard case .denied(.token, _)? = back.sent.first else {
            Issue.record("A forgotten token was welcomed")
            return
        }
        let paired = connect(remote, hello(code: hub.server.pairingCode.digits))
        #expect(issuedToken(paired) != nil)
    }

    @Test("remembers a device across a relaunch, and forgets them all at once")
    func relaunch() throws {
        let store = InMemoryPairedDevices()
        let first = sessions(store: store)
        let channel = connect(first, hello(code: hub.server.pairingCode.digits))
        let token = try #require(issuedToken(channel))
        #expect(hub.session(.live("3f2a"))?.pairedDeviceID == hub.pairedDevices.first?.id)
        channel.close()

        let hub = SessionHub()
        let relaunched = PeekRemoteSessions(hub: hub, serverVersion: "1.0", serverID: "mac-1", pairedDevices: store)
        #expect(hub.pairedDevices.count == 1)
        let back = FakeChannel(address: "192.168.1.40")
        relaunched.accept(back)
        back.receive(hello(token: token))
        #expect(back.sent.first == .welcome(serverName: "Peek Pro", serverVersion: "1.0", serverID: "mac-1"))
        #expect(store.devices.first?.address == "192.168.1.40")
        #expect(hub.session(.live("3f2a"))?.pairedDeviceID == store.devices.first?.id)

        relaunched.forgetAllDevices()
        #expect(back.isClosed)
        #expect(hub.pairedDevices.isEmpty)
        #expect(store.devices.isEmpty && store.tokens.isEmpty)
        #expect(hub.session(.live("3f2a"))?.pairedDeviceID == nil)
    }

    @Test("a new code on request stops the old one")
    func onRequest() {
        let remote = sessions()
        let shown = hub.server.pairingCode
        remote.rotateCode()
        #expect(hub.server.pairingCode != shown)
        let channel = connect(remote, hello(code: shown.digits))
        guard case .denied(.code, _)? = channel.sent.first else {
            Issue.record("An old code was accepted")
            return
        }
    }
}
