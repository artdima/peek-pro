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
    var token: String
}

nonisolated struct PeekRejectedConnection: Identifiable, Hashable, Sendable {
    nonisolated enum Reason: Hashable, Sendable {
        case invalidToken
        case unsupportedProtocol(version: Int)
    }

    let id: String
    let address: String
    let name: String?
    let platform: PeekPlatform?
    let reason: Reason
    let at: Date
}
