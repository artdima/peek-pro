import Foundation

/// Peek's one-tap presets over the filtered list — they stand where Pulse has Network / Logs / All.
nonisolated enum ConsoleQuickMode: String, CaseIterable, Identifiable, Sendable {
    case all
    case errors
    case pending
    case pinned

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .errors: "Errors"
        case .pending: "Pending"
        case .pinned: "Pinned"
        }
    }

    func matches(_ entry: PeekEntry) -> Bool {
        switch self {
        case .all: true
        case .errors: entry.isError
        case .pending: entry.state == .pending
        case .pinned: entry.isPinned
        }
    }
}
