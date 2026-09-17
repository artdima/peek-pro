import Foundation

/// Where the tokens issued to paired devices live; the hub lists the devices, this holds their secrets.
protocol PeekDeviceTokens: AnyObject {
    /// Every token, with the device it was issued to.
    var all: [String: String] { get }
    func add(_ token: String, for deviceID: String)
    func remove(deviceID: String)
}

/// Gone with the process; the Keychain store comes with the paired-devices list in Settings.
final class InMemoryDeviceTokens: PeekDeviceTokens {
    private(set) var all: [String: String] = [:]

    init() {}

    func add(_ token: String, for deviceID: String) {
        all[token] = deviceID
    }

    func remove(deviceID: String) {
        all = all.filter { $0.value != deviceID }
    }
}
