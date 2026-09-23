import Foundation
import Security
import Testing
@testable import Peek_Pro

@MainActor
@Suite("Paired devices in the Keychain", .serialized)
struct KeychainPairedDevicesTests {
    /// Its own service and defaults key, so the tests never touch what the app keeps.
    private static let service = "com.artdima.Peek-Pro.device-tokens.tests"
    private static let key = "tests.pairedDevices"

    private func store() -> KeychainPairedDevices {
        KeychainPairedDevices(service: Self.service, key: Self.key)
    }

    private func device(_ id: String, address: String = "192.168.1.20") -> PeekPairedDevice {
        PeekPairedDevice(id: id, name: "Acme Shop", platform: .iOS, address: address, pairedAt: Date(timeIntervalSince1970: 1_790_000_000), lastSeenAt: Date(timeIntervalSince1970: 1_790_000_100))
    }

    @Test("keeps devices and tokens for the next launch")
    func persists() {
        store().removeAll()
        defer { store().removeAll() }
        let first = store()
        first.add(device("a"), token: "token-a")
        first.add(device("b", address: "192.168.1.21"), token: "token-b")
        var seen = device("a")
        seen.address = "10.0.0.5"
        seen.lastSeenAt = Date(timeIntervalSince1970: 1_790_000_200)
        first.update(seen)

        let next = store()
        if let failure = KeychainPairedDevices.lastFailure {
            Issue.record("Keychain \(failure.call) failed: \(failure.status) \(SecCopyErrorMessageString(failure.status, nil) as String? ?? "")")
        }
        #expect(next.devices == [seen, device("b", address: "192.168.1.21")])
        #expect(next.tokens == ["token-a": "a", "token-b": "b"])

        next.remove("a")
        #expect(store().devices.map(\.id) == ["b"])
        #expect(store().tokens == ["token-b": "b"])
        next.removeAll()
        #expect(store().devices.isEmpty)
        #expect(store().tokens.isEmpty)
    }

    @Test("drops a device whose token is gone, and a token whose device is")
    func consistency() {
        store().removeAll()
        defer { store().removeAll() }
        let first = store()
        first.add(device("a"), token: "token-a")
        first.add(device("b"), token: "token-b")
        UserDefaults.standard.set(try? JSONEncoder().encode([device("a"), device("c")]), forKey: Self.key)

        let next = store()
        #expect(next.devices.map(\.id) == ["a"])
        #expect(next.tokens == ["token-a": "a"])
    }

    @Test("writes the platform by name, so a newer one still reads")
    func codable() throws {
        let data = try JSONEncoder().encode([device("a")])
        #expect(String(decoding: data, as: UTF8.self).contains(#""platform":"ios""#))
        let odd = #"[{"id":"z","platform":"visionos","address":"1.2.3.4","pairedAt":0,"lastSeenAt":0}]"#
        let decoded = try JSONDecoder().decode([PeekPairedDevice].self, from: Data(odd.utf8))
        #expect(decoded.first?.platform == .other("visionos"))
        #expect(decoded.first?.name == nil)
    }
}
