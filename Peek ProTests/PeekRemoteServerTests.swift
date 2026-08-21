import Foundation
import Network
import Testing
@testable import Peek_Pro

@MainActor
@Suite("Remote server", .serialized)
struct PeekRemoteServerTests {
    /// A port nothing else here uses; random so a leftover listener from another run can't clash.
    private func freePort() -> Int {
        Int.random(in: 49_152...60_999)
    }

    /// Polls, since the listener reports on the main queue.
    private func eventually(_ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition() {
            if ContinuousClock.now >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return true
    }

    @Test("listens on the port it was given")
    func listens() async {
        let port = freePort()
        let server = PeekRemoteServer(port: port)
        server.start()
        defer { server.stop() }
        #expect(await eventually { server.state == .listening })
        #expect(server.port == port)
    }

    @Test("reports a port another listener holds")
    func portInUse() async {
        let port = freePort()
        let first = PeekRemoteServer(port: port)
        first.start()
        defer { first.stop() }
        #expect(await eventually { first.state == .listening })

        let second = PeekRemoteServer(port: port)
        var reported: [PeekRemoteServer.State] = []
        second.onStateChange = { reported.append($0) }
        second.start()
        defer { second.stop() }
        #expect(await eventually { second.state == .portInUse })
        #expect(reported == [.portInUse])
    }

    @Test("takes the port back once it's free")
    func retakesPort() async {
        let port = freePort()
        let first = PeekRemoteServer(port: port)
        first.start()
        #expect(await eventually { first.state == .listening })
        let second = PeekRemoteServer(port: port)
        second.start()
        defer { second.stop() }
        #expect(await eventually { second.state == .portInUse })

        // The port frees up once the cancel lands, so retry the way PeekRemoteHost does.
        first.stop()
        #expect(await eventually {
            if second.state == .portInUse { second.start() }
            return second.state == .listening
        })
    }

    @Test("moves to another port")
    func restarts() async {
        let server = PeekRemoteServer(port: freePort())
        server.start()
        defer { server.stop() }
        #expect(await eventually { server.state == .listening })
        let port = server.port + 1
        server.restart(on: port)
        #expect(server.port == port)
        #expect(await eventually { server.state == .listening })
    }

    @Test("refuses a port out of range")
    func invalidPort() {
        let server = PeekRemoteServer(port: 70_000)
        server.start()
        guard case .failed = server.state else {
            Issue.record("Expected a failure, got \(server.state)")
            return
        }
    }

    @Test("goes idle when stopped")
    func stops() async {
        let server = PeekRemoteServer(port: freePort())
        server.start()
        #expect(await eventually { server.state == .listening })
        server.stop()
        #expect(server.state == .idle)
        #expect(server.connections.isEmpty)
    }

    @Test("lists local IPv4 addresses without loopback")
    func addresses() {
        let addresses = PeekRemoteServer.localAddresses()
        #expect(!addresses.contains("127.0.0.1"))
        #expect(Set(addresses).count == addresses.count)
        #expect(addresses.allSatisfy { IPv4Address($0) != nil })
    }

    @Test("writes a device's address as a person would type it")
    func connectionAddress() {
        func address(_ host: NWEndpoint.Host) -> String {
            PeekRemoteConnection.address(of: .hostPort(host: host, port: 50_000))
        }
        #expect(address(.ipv4(IPv4Address("192.168.1.5")!)) == "192.168.1.5")
        #expect(address(.ipv6(IPv6Address("::ffff:192.168.1.5")!)) == "192.168.1.5")
        #expect(address(.ipv6(IPv6Address("fe80::1%lo0")!)) == "fe80::1")
        #expect(address(.name("iPhone.local", nil)) == "iPhone.local")
    }
}

@MainActor
@Suite("Server token")
struct ServerTokenTests {
    @Test("keeps the stored token only when the policy says so")
    func launchToken() {
        #expect(PeekServerState.launchToken(policy: .persistent, stored: "abcd-efgh-jkmn") == "abcd-efgh-jkmn")
        #expect(PeekServerState.launchToken(policy: .perLaunch, stored: "abcd-efgh-jkmn") != "abcd-efgh-jkmn")
        #expect(PeekServerState.launchToken(policy: .persistent, stored: nil).count == 14)
        #expect(PeekServerState.launchToken(policy: .persistent, stored: "").count == 14)
    }
}
