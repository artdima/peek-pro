import Foundation

/// A platform a newer Peek names that this build doesn't know is kept as `other` and shown as it came.
nonisolated enum PeekPlatform: Hashable, Sendable {
    case iOS
    case android
    case macOS
    case windows
    case linux
    case fuchsia
    case web
    /// Peek on the device couldn't tell.
    case unknown
    case other(String)

    init(rawValue: String) {
        self = switch rawValue {
        case "ios": .iOS
        case "android": .android
        case "macos": .macOS
        case "windows": .windows
        case "linux": .linux
        case "fuchsia": .fuchsia
        case "web": .web
        case "unknown": .unknown
        default: .other(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .iOS: "ios"
        case .android: "android"
        case .macOS: "macos"
        case .windows: "windows"
        case .linux: "linux"
        case .fuchsia: "fuchsia"
        case .web: "web"
        case .unknown: "unknown"
        case .other(let value): value
        }
    }
}

/// What a client says about itself: the `.peek` file header and the `hello` frame.
/// Pure Dart can't learn an app's name, bundle id or the device model without a plugin, so none of them are here.
nonisolated struct PeekSessionInfo: Hashable, Sendable {
    /// Given by the app in `PeekRemote(name:)`, if it chose to.
    let name: String?
    let platform: PeekPlatform
    /// Only where Dart reports it readably (iOS, macOS); Android gives the Linux kernel, so it stays `nil`.
    let osVersion: String?
    let peekVersion: String
    let startedAt: Date

    /// "iOS 26.0", or just "Android" when the version isn't known.
    var systemTitle: String {
        osVersion.map { "\(platform.title) \($0)" } ?? platform.title
    }
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

    /// The name the app gave, or its platform and address when it gave none.
    var title: String {
        info.name ?? "\(info.platform.title) · \(address)"
    }
}

nonisolated struct PeekSessionFile: Identifiable, Hashable, Sendable {
    let url: URL
    let byteCount: Int
    let modifiedAt: Date
    let info: PeekSessionInfo
    let formatVersion: Int
    /// Lines the reader could not decode and skipped.
    let skippedLines: Int
    var failure: PeekFileFailure? = nil

    /// The newest session format this build reads fully.
    static let supportedFormatVersion = 1

    var id: PeekSessionID { .file(url) }
    var name: String { url.lastPathComponent }
    /// Written by a newer Peek: read anyway, but fields this build doesn't know are skipped.
    var isNewerFormat: Bool { formatVersion > Self.supportedFormatVersion }
    var hasWarnings: Bool { isNewerFormat || skippedLines > 0 }
}

nonisolated enum PeekFileFailure: Hashable, Sendable {
    /// The header was read, but the format predates what this build can read.
    case unsupportedFormat(version: Int)
}
