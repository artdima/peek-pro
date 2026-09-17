import Foundation

nonisolated struct PeekServerState: Hashable, Sendable {
    nonisolated enum Status: Hashable, Sendable {
        case listening
        case portInUse
    }

    var status: Status
    var port: Int
    var addresses: [String]
    var bonjourName: String?
    /// For apps with the token written in code; a person at a device types `pairingCode` instead.
    var token: String
    var pairingCode: PeekPairingCode = .random()
}

/// Four digits a person types into the app once; the desktop answers with a token that lasts.
nonisolated struct PeekPairingCode: Hashable, Sendable {
    /// Read out in pairs and typed on a phone: four digits, leading zeros kept.
    static let digitCount = 4
    static let defaultLifetime: TimeInterval = 5 * 60

    let digits: String
    let issuedAt: Date
    let expiresAt: Date

    static func random(lifetime: TimeInterval = defaultLifetime, now: Date = .now) -> PeekPairingCode {
        var generator = SystemRandomNumberGenerator()
        let value = Int.random(in: 0..<10_000, using: &generator)
        let digits = String(repeating: "0", count: digitCount - String(value).count) + String(value)
        return PeekPairingCode(digits: digits, issuedAt: now, expiresAt: now.addingTimeInterval(lifetime))
    }

    func isExpired(at date: Date = .now) -> Bool {
        date >= expiresAt
    }

    /// "4 7 1 9", as it is shown.
    var spaced: String {
        digits.map(String.init).joined(separator: " ")
    }
}

/// A device that paired with a code; its token lives elsewhere, this is what Settings lists.
nonisolated struct PeekPairedDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String?
    let platform: PeekPlatform
    var address: String
    let pairedAt: Date
    var lastSeenAt: Date

    var title: String {
        name ?? "\(platform.title) · \(address)"
    }
}

nonisolated struct PeekRejectedConnection: Identifiable, Hashable, Sendable {
    nonisolated enum Reason: Hashable, Sendable {
        case invalidToken
        case wrongCode
        case unsupportedProtocol(version: Int)
    }

    let id: String
    let address: String
    let name: String?
    let platform: PeekPlatform?
    let reason: Reason
    let at: Date
}
