import Foundation

nonisolated enum PeekPlatform: String, CaseIterable, Sendable {
    case iOS = "ios"
    case android
    case macOS = "macos"
    case windows
    case linux
    case web
}

nonisolated struct PeekApp: Hashable, Sendable {
    let name: String
    /// Bundle id or package name.
    let identifier: String
    let version: String?
}

nonisolated struct PeekDevice: Hashable, Sendable {
    let name: String
    let model: String?
    let platform: PeekPlatform
    let osVersion: String
    let isSimulator: Bool
}

/// What the device says about itself: the `.peek` file header and the `hello` frame.
nonisolated struct PeekSessionInfo: Hashable, Sendable {
    let app: PeekApp
    let device: PeekDevice
    let peekVersion: String
    let startedAt: Date
}

nonisolated enum PeekSessionID: Hashable, Sendable {
    case live(String)
    case file(URL)
}

nonisolated enum PeekConnectionState: Hashable, Sendable {
    case connecting
    case connected
    case disconnected
}

nonisolated struct PeekLiveSession: Identifiable, Hashable, Sendable {
    let key: String
    let info: PeekSessionInfo
    var connection: PeekConnectionState
    let address: String
    let connectedAt: Date
    var disconnectedAt: Date?
    /// Entries the device threw away because its send queue overflowed.
    var droppedCount: Int

    var id: PeekSessionID { .live(key) }
}

nonisolated struct PeekSessionFile: Identifiable, Hashable, Sendable {
    let url: URL
    let byteCount: Int
    let modifiedAt: Date
    let info: PeekSessionInfo
    let formatVersion: Int
    /// Lines the reader could not decode and skipped.
    let skippedLines: Int

    var id: PeekSessionID { .file(url) }
    var name: String { url.lastPathComponent }
}
