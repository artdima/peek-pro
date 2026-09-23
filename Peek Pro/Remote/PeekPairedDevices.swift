import Foundation
import Security

/// Where paired devices and their tokens live between launches; the hub shows the devices, this keeps them.
protocol PeekPairedDevices: AnyObject {
    var devices: [PeekPairedDevice] { get }
    /// Every token, with the device it was issued to.
    var tokens: [String: String] { get }
    func add(_ device: PeekPairedDevice, token: String)
    /// A device seen again: its address and time.
    func update(_ device: PeekPairedDevice)
    func remove(_ id: String)
    func removeAll()
}

/// Gone with the process: tests and previews.
final class InMemoryPairedDevices: PeekPairedDevices {
    private(set) var devices: [PeekPairedDevice] = []
    private(set) var tokens: [String: String] = [:]

    init() {}

    func add(_ device: PeekPairedDevice, token: String) {
        devices.removeAll { $0.id == device.id }
        devices.append(device)
        tokens[token] = device.id
    }

    func update(_ device: PeekPairedDevice) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index] = device
    }

    func remove(_ id: String) {
        devices.removeAll { $0.id == id }
        tokens = tokens.filter { $0.value != id }
    }

    func removeAll() {
        devices = []
        tokens = [:]
    }
}

/// The list in the defaults, the tokens in the Keychain: a token is a key to this Mac's traffic view, and
/// the defaults are a plain file.
final class KeychainPairedDevices: PeekPairedDevices {
    static let defaultService = "com.artdima.Peek-Pro.device-tokens"

    private(set) var devices: [PeekPairedDevice]
    private(set) var tokens: [String: String]
    /// The last Keychain call that failed, for the tests and the log.
    private(set) static var lastFailure: (call: String, status: OSStatus)?
    private let service: String
    private let defaults: UserDefaults
    private let key: String

    init(service: String = defaultService, defaults: UserDefaults = .standard, key: String = SettingsKey.pairedDevices) {
        self.service = service
        self.defaults = defaults
        self.key = key
        let stored = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([PeekPairedDevice].self, from: $0) } ?? []
        let read = Self.readTokens(service: service)
        // A device without a token can never connect; one without a record is a stray. Neither is kept.
        devices = stored.filter { device in read.values.contains(device.id) }
        tokens = read.filter { token in stored.contains { $0.id == token.value } }
    }

    func add(_ device: PeekPairedDevice, token: String) {
        devices.removeAll { $0.id == device.id }
        devices.append(device)
        tokens[token] = device.id
        Self.write(token: token, for: device.id, service: service)
        save()
    }

    func update(_ device: PeekPairedDevice) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index] = device
        save()
    }

    func remove(_ id: String) {
        devices.removeAll { $0.id == id }
        tokens = tokens.filter { $0.value != id }
        Self.delete(deviceID: id, service: service)
        save()
    }

    func removeAll() {
        devices = []
        tokens = [:]
        Self.delete(deviceID: nil, service: service)
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(devices), forKey: key)
    }

    // MARK: Keychain

    /// The login keychain, one generic-password item per device: the sandbox lets only this app at them.
    /// (The data-protection keychain would need an application identifier the local signature lacks.)
    private static func query(service: String, deviceID: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let deviceID { query[kSecAttrAccount as String] = deviceID }
        return query
    }

    /// The accounts first, then each secret on its own: the login keychain hands out data one item at a time.
    private static func readTokens(service: String) -> [String: String] {
        var listing = query(service: service, deviceID: nil)
        listing[kSecMatchLimit as String] = kSecMatchLimitAll
        listing[kSecReturnAttributes as String] = true
        var found: CFTypeRef?
        let listed = SecItemCopyMatching(listing as CFDictionary, &found)
        guard listed == errSecSuccess, let items = found as? [[String: Any]] else {
            if listed != errSecItemNotFound { note("list", listed) }
            return [:]
        }
        var tokens: [String: String] = [:]
        for item in items {
            guard let id = item[kSecAttrAccount as String] as? String else { continue }
            var one = query(service: service, deviceID: id)
            one[kSecMatchLimit as String] = kSecMatchLimitOne
            one[kSecReturnData as String] = true
            var data: CFTypeRef?
            let read = SecItemCopyMatching(one as CFDictionary, &data)
            guard read == errSecSuccess, let bytes = data as? Data, let token = String(data: bytes, encoding: .utf8) else {
                note("read", read)
                continue
            }
            tokens[token] = id
        }
        return tokens
    }

    private static func write(token: String, for deviceID: String, service: String) {
        var query = query(service: service, deviceID: deviceID)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrLabel as String] = "Peek Pro paired device"
        let added = SecItemAdd(query as CFDictionary, nil)
        if added != errSecSuccess { note("add", added) }
    }

    private static func delete(deviceID: String?, service: String) {
        let deleted = SecItemDelete(query(service: service, deviceID: deviceID) as CFDictionary)
        if deleted != errSecSuccess, deleted != errSecItemNotFound { note("delete", deleted) }
    }

    private static func note(_ call: String, _ status: OSStatus) {
        lastFailure = (call, status)
        NSLog("Peek Pro keychain: %@ failed with %d (%@)", call, status, SecCopyErrorMessageString(status, nil) as String? ?? "")
    }
}
