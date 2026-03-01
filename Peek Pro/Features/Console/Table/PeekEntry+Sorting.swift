import Foundation

/// Comparable stand-ins for optional columns, so the table can sort by key path; missing values sort first.
extension PeekEntry {
    nonisolated var sortStatus: Int { statusCode ?? (failure != nil ? 1_000 : -1) }
    nonisolated var sortMethod: String { request.method }
    nonisolated var sortURL: String { request.uri.absoluteString }
    nonisolated var sortDuration: Double { duration?.timeInterval ?? -1 }
    nonisolated var sortRequestSize: Int { requestSize ?? -1 }
    nonisolated var sortResponseSize: Int { responseSize ?? -1 }
    nonisolated var sortSource: String { source }
    nonisolated var sortPinned: Int { isPinned ? 1 : 0 }
}
