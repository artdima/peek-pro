import Foundation

nonisolated enum ConsoleSortColumn: String, CaseIterable, Sendable {
    case status
    case method
    case url
    case startedAt
    case duration
    case requestSize
    case responseSize
    case source
    case pinned

    var field: PeekSortField? {
        switch self {
        case .status: .statusCode
        case .startedAt: .startedAt
        case .duration: .duration
        case .requestSize: .requestSize
        case .responseSize: .responseSize
        case .method, .url, .source, .pinned: nil
        }
    }
}

/// The table's sort. Numeric columns go through `PeekSort`, so a pending call stays at the bottom by duration either way.
nonisolated struct ConsoleSort: SortComparator, Hashable, Sendable {
    /// Oldest first: new requests arrive at the bottom, as in Pulse.
    static let `default` = ConsoleSort(.startedAt)

    var column: ConsoleSortColumn
    var order: SortOrder

    init(_ column: ConsoleSortColumn, order: SortOrder = .forward) {
        self.column = column
        self.order = order
    }

    /// `"duration:reverse"` — for `@SceneStorage`.
    init?(storage: String) {
        let parts = storage.split(separator: ":").map(String.init)
        guard parts.count == 2, let column = ConsoleSortColumn(rawValue: parts[0]) else { return nil }
        switch parts[1] {
        case "forward": self.init(column, order: .forward)
        case "reverse": self.init(column, order: .reverse)
        default: return nil
        }
    }

    var storage: String { "\(column.rawValue):\(order == .forward ? "forward" : "reverse")" }

    func compare(_ lhs: PeekEntry, _ rhs: PeekEntry) -> ComparisonResult {
        if let field = column.field {
            return PeekSort(field: field, descending: order == .reverse).compare(lhs, rhs)
        }
        let result: ComparisonResult = switch column {
        case .method: lhs.request.method.compare(rhs.request.method)
        case .url: lhs.request.uri.absoluteString.localizedStandardCompare(rhs.request.uri.absoluteString)
        case .source: lhs.source.localizedStandardCompare(rhs.source)
        // Pinned first on the first click — that's what the column is clicked for.
        case .pinned: lhs.isPinned == rhs.isPinned ? .orderedSame : lhs.isPinned ? .orderedAscending : .orderedDescending
        default: .orderedSame
        }
        return order == .forward ? result : result.reversed
    }

    func apply(_ entries: [PeekEntry]) -> [PeekEntry] {
        guard self != .default else { return entries.isSortedByStart ? entries : entries.stableSorted(by: compare) }
        return entries.stableSorted(by: compare)
    }
}

nonisolated extension ComparisonResult {
    var reversed: ComparisonResult {
        switch self {
        case .orderedAscending: .orderedDescending
        case .orderedDescending: .orderedAscending
        case .orderedSame: .orderedSame
        }
    }
}

nonisolated extension [PeekEntry] {
    /// Entries usually arrive in start order; checking is O(n) and saves the sort on every change of a live session.
    var isSortedByStart: Bool {
        zip(self, dropFirst()).allSatisfy { $0.startedAt <= $1.startedAt }
    }
}
