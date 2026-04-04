import Foundation

nonisolated enum PeekBodySide: String, Hashable, Sendable {
    case request
    case response
}

/// Which body to fetch from the device — mirrors `PeekBodyLoader.load(id, side)` in Peek.
nonisolated struct PeekBodyLoadKey: Hashable, Sendable {
    let entryID: PeekId
    let side: PeekBodySide
}

nonisolated enum PeekBodyLoadState: Equatable, Sendable {
    case loading
    case failed(String)
}
