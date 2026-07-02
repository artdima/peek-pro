import Foundation

nonisolated enum PeekSortField: String, CaseIterable, Sendable {
    case startedAt
    case duration
    case responseSize
    case requestSize
    case statusCode
}

/// Mirrors `PeekSort` from Peek core. Stable, so equal entries keep the order they came in;
/// an entry without a value for `field` — a pending call sorted by duration — comes last whichever way the sort runs.
nonisolated struct PeekSort: Hashable, Sendable {
    static let newestFirst = PeekSort()
    static let oldestFirst = PeekSort(descending: false)
    static let slowestFirst = PeekSort(field: .duration)
    static let largestFirst = PeekSort(field: .responseSize)

    var field: PeekSortField
    var descending: Bool

    init(field: PeekSortField = .startedAt, descending: Bool = true) {
        self.field = field
        self.descending = descending
    }

    func compare(_ lhs: PeekEntry, _ rhs: PeekEntry) -> ComparisonResult {
        switch (key(lhs), key(rhs)) {
        case (nil, nil): .orderedSame
        case (nil, _): .orderedDescending
        case (_, nil): .orderedAscending
        case let (left?, right?):
            left == right ? .orderedSame : (left < right) != descending ? .orderedAscending : .orderedDescending
        }
    }

    func apply(_ entries: [PeekEntry]) -> [PeekEntry] {
        entries.stableSorted { compare($0, $1) }
    }

    private func key(_ entry: PeekEntry) -> Int64? {
        switch field {
        case .startedAt: entry.startedAt.microsecondsSince1970
        case .duration: entry.duration.map(\.inMicroseconds)
        case .responseSize: entry.responseSize.map(Int64.init)
        case .requestSize: entry.requestSize.map(Int64.init)
        case .statusCode: entry.statusCode.map(Int64.init)
        }
    }
}

nonisolated extension Array {
    /// Ties keep their original order, which `sorted(by:)` doesn't promise.
    func stableSorted(by compare: (Element, Element) -> ComparisonResult) -> [Element] {
        enumerated()
            .sorted { lhs, rhs in
                switch compare(lhs.element, rhs.element) {
                case .orderedAscending: true
                case .orderedDescending: false
                case .orderedSame: lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }
}

nonisolated extension Date {
    var microsecondsSince1970: Int64 { Int64((timeIntervalSince1970 * 1_000_000).rounded()) }
}

nonisolated extension Duration {
    var inMicroseconds: Int64 {
        let (seconds, attoseconds) = components
        return seconds * 1_000_000 + attoseconds / 1_000_000_000_000
    }
}
