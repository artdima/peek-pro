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

    /// Unique, so a Peek Pro running on this Mac can't take the name first.
    private func testName() -> String {
        "Peek Pro Test \(UUID().uuidString.prefix(8))"
    }

    @Test("advertises over Bonjour under the name it was given")
    func advertises() async {
        let name = testName()
        let server = PeekRemoteServer(port: freePort())
        server.serviceName = name
        var reported: [String?] = []
        server.onServiceChange = { reported.append($0) }
        server.start()
        defer { server.stop() }
        #expect(await eventually { server.registeredName == name })
        #expect(reported == [name])
    }

    @Test("stays quiet without a name")
    func quiet() async {
        let server = PeekRemoteServer(port: freePort())
        server.start()
        defer { server.stop() }
        #expect(await eventually { server.state == .listening })
        try? await Task.sleep(for: .milliseconds(300))
        #expect(server.registeredName == nil)
    }

    @Test("changes the name, and stops advertising, without a restart")
    func renames() async {
        let first = testName(), second = testName()
        let server = PeekRemoteServer(port: freePort())
        server.serviceName = first
        server.start()
        defer { server.stop() }
        #expect(await eventually { server.registeredName == first })

        server.serviceName = second
        #expect(await eventually { server.registeredName == second })
        #expect(server.state == .listening)

        server.serviceName = nil
        #expect(await eventually { server.registeredName == nil })
        #expect(server.state == .listening)
    }

    @Test("forgets the registered name when stopped")
    func stopsAdvertising() async {
        let server = PeekRemoteServer(port: freePort())
        server.serviceName = testName()
        server.start()
        #expect(await eventually { server.registeredName != nil })
        server.stop()
        #expect(server.registeredName == nil)
    }

    @Test("tells which desktop this is in the TXT record")
    func txtRecord() {
        #expect(PeekRemoteServer.txtRecord(serverID: "desk-1") == ["protocolVersion": "1", "serverId": "desk-1"])
        #expect(PeekRemoteServer.txtRecord(serverID: nil) == ["protocolVersion": "1"])
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
@Suite("Bonjour name")
struct BonjourNameTests {
    @Test("is the Mac's name unless another was typed, and nothing when off")
    func fromSettings() {
        let mac = PeekServerState.defaultBonjourName
        #expect(!mac.isEmpty)
        #expect(PeekServerState.bonjourName(enabled: nil, custom: nil) == mac)
        #expect(PeekServerState.bonjourName(enabled: true, custom: "") == mac)
        #expect(PeekServerState.bonjourName(enabled: true, custom: "  ") == mac)
        #expect(PeekServerState.bonjourName(enabled: true, custom: " Dev Mac ") == "Dev Mac")
        #expect(PeekServerState.bonjourName(enabled: false, custom: "Dev Mac") == nil)
    }

    @Test("fits Bonjour's 63 bytes without cutting a character in half")
    func limit() {
        let long = String(repeating: "é", count: 40)
        let fitted = PeekServerState.fitBonjour(long)
        #expect(fitted.utf8.count == 62)
        #expect(fitted.count == 31)
        #expect(PeekServerState.fitBonjour("MacBook Pro") == "MacBook Pro")
        #expect(PeekServerState.bonjourName(enabled: true, custom: long)?.utf8.count == 62)
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
