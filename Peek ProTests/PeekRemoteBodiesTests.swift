import Foundation
import Testing
@testable import Peek_Pro

@MainActor
@Suite("Remote bodies on demand")
struct PeekRemoteBodiesTests {
    private let hub = SessionHub(server: PeekServerState(
        status: .listening,
        port: 9741,
        addresses: [],
        bonjourName: nil,
        token: "k7q4-mx2p-9vd3"
    ))
    private let id = PeekSessionID.live("3f2a")
    private let key = PeekBodyLoadKey(entryID: PeekId("n1"), side: .response)

    /// A finished call whose response body stayed on the device.
    private var held: PeekEntry {
        let template = Fixtures.entry("f02")
        let entry = template.restarted(id: PeekId("n1"), at: Fixtures.start).finished(like: template)
        return entry.replacingBody(.remote(size: 8_090, contentType: .json, isTruncated: false), on: .response)
    }

    private func hello(_ session: String = "3f2a") -> PeekRemoteFrame {
        .hello(PeekRemoteHello(
            protocolVersion: PeekRemoteProtocol.version,
            token: "k7q4-mx2p-9vd3",
            sessionID: session,
            info: PeekSessionInfo(name: "Acme Shop", platform: .iOS, osVersion: "26.0", peekVersion: "1.4.0", startedAt: .now)
        ))
    }

    private func connect(_ remote: PeekRemoteSessions, session: String = "3f2a") -> FakeChannel {
        let channel = FakeChannel()
        remote.accept(channel)
        channel.receive(hello(session))
        channel.receive(.entryAdded(held))
        channel.receive(.synced(count: 1))
        return channel
    }

    private func loader(_ remote: PeekRemoteSessions) {
        hub.bodyLoader = { [hub] key, id in
            if !remote.loadBody(key, in: id) { hub.failBodyLoad(key, in: id, message: "not ours") }
        }
    }

    /// The `bodyRequest` the device got last.
    private func lastRequest(_ channel: FakeChannel) -> (requestID: String, entryID: PeekId, side: PeekBodySide)? {
        for frame in channel.sent.reversed() {
            if case .bodyRequest(let requestID, let entryID, let side) = frame { return (requestID, entryID, side) }
        }
        return nil
    }

    @Test("asks the device and puts the body in place")
    func loads() throws {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        loader(remote)
        let channel = connect(remote)
        hub.loadBody(key, in: id)
        #expect(hub.bodyLoad(key, in: id) == .loading)

        let request = try #require(lastRequest(channel))
        #expect(request.entryID == PeekId("n1"))
        #expect(request.side == .response)
        channel.receive(.bodyResponse(requestID: request.requestID, body: .text("{\"ok\":true}", contentType: .json)))
        #expect(hub.bodyLoad(key, in: id) == nil)
        #expect(hub.entry(PeekId("n1"), in: id)?.response?.body == .text("{\"ok\":true}", contentType: .json))
    }

    @Test("asks once while a load is under way")
    func onceAtATime() {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        loader(remote)
        let channel = connect(remote)
        hub.loadBody(key, in: id)
        hub.loadBody(key, in: id)
        #expect(channel.sent.filter { if case .bodyRequest = $0 { true } else { false } }.count == 1)
    }

    @Test("shows why the device had no body, and asks again on Try Again")
    func error() throws {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        loader(remote)
        let channel = connect(remote)
        hub.loadBody(key, in: id)
        let first = try #require(lastRequest(channel))
        channel.receive(.bodyError(requestID: first.requestID, error: .notHeld, message: nil))
        #expect(hub.bodyLoad(key, in: id) == .failed("The device didn't keep this body."))

        hub.loadBody(key, in: id)
        let second = try #require(lastRequest(channel))
        #expect(second.requestID != first.requestID)
        channel.receive(.bodyError(requestID: second.requestID, error: .failed, message: "Disk full"))
        #expect(hub.bodyLoad(key, in: id) == .failed("Disk full"))
    }

    @Test("gives up when the device doesn't answer, and ignores a late answer")
    func timeout() async throws {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        remote.bodyTimeout = .milliseconds(30)
        loader(remote)
        let channel = connect(remote)
        hub.loadBody(key, in: id)
        let request = try #require(lastRequest(channel))
        try await Task.sleep(for: .milliseconds(200))
        guard case .failed? = hub.bodyLoad(key, in: id) else {
            Issue.record("Expected a failure, got \(String(describing: hub.bodyLoad(key, in: id)))")
            return
        }
        channel.receive(.bodyResponse(requestID: request.requestID, body: .text("late")))
        guard case .remote? = hub.entry(PeekId("n1"), in: id)?.response?.body else {
            Issue.record("A late answer replaced the body")
            return
        }
    }

    @Test("fails what's in flight when the device goes, and says it's offline after")
    func offline() throws {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        loader(remote)
        let channel = connect(remote)
        hub.loadBody(key, in: id)
        channel.close()
        #expect(hub.bodyLoad(key, in: id) == .failed("The device disconnected before sending the body."))
        hub.loadBody(key, in: id)
        #expect(hub.bodyLoad(key, in: id) == .failed("The device is offline. Reconnect it to load the body."))
    }

    @Test("takes an answer only from the device that was asked")
    func otherDevice() throws {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        loader(remote)
        let asked = connect(remote)
        let other = connect(remote, session: "other")
        hub.loadBody(key, in: id)
        let request = try #require(lastRequest(asked))
        other.receive(.bodyResponse(requestID: request.requestID, body: .text("wrong")))
        #expect(hub.bodyLoad(key, in: id) == .loading)
    }

    @Test("leaves sessions it didn't open to another loader")
    func notOurs() {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        loader(remote)
        hub.loadBody(key, in: .live("iphone"))
        #expect(hub.bodyLoad(key, in: .live("iphone")) == .failed("not ours"))
    }

    @Test("keeps a fetched body when the device sends the call again")
    func keepsLoaded() throws {
        let remote = PeekRemoteSessions(hub: hub, serverID: "mac-1")
        loader(remote)
        let channel = connect(remote)
        hub.loadBody(key, in: id)
        let request = try #require(lastRequest(channel))
        channel.receive(.bodyResponse(requestID: request.requestID, body: .text("full")))

        channel.receive(.entryUpdated(held))
        #expect(hub.entry(PeekId("n1"), in: id)?.response?.body == .text("full"))

        // And across a reconnection's history.
        channel.close()
        let again = FakeChannel()
        remote.accept(again)
        again.receive(hello())
        again.receive(.entryAdded(held))
        again.receive(.synced(count: 1))
        #expect(hub.entry(PeekId("n1"), in: id)?.response?.body == .text("full"))
    }

    @Test("keeps loads apart per session")
    func perSession() {
        hub.failBodyLoad(key, in: .live("a"), message: "a")
        #expect(hub.bodyLoad(key, in: .live("b")) == nil)
        #expect(hub.bodyLoad(key, in: .live("a")) == .failed("a"))
    }
}
