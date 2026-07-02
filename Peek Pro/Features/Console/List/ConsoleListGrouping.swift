import Foundation

nonisolated enum ConsoleListGrouping: String, CaseIterable, Identifiable, Sendable {
    case status
    case host
    case source
    case none

    static let storageKey = "consoleListGrouping"

    var id: Self { self }

    var title: String {
        switch self {
        case .status: "Status"
        case .host: "Host"
        case .source: "Source"
        case .none: "None"
        }
    }
}

nonisolated struct ConsoleListSection: Identifiable, Sendable {
    let id: String
    let title: String?
    let entries: [PeekEntry]
}

extension ConsoleListGrouping {
    /// Oldest first inside a section; status sections go by code, then failures, then pending — as Pulse orders them.
    nonisolated func sections(of entries: [PeekEntry]) -> [ConsoleListSection] {
        let ordered = PeekSort.oldestFirst.apply(entries)
        guard self != .none else {
            return [ConsoleListSection(id: "all", title: nil, entries: ordered)]
        }
        var groups: [Group: [PeekEntry]] = [:]
        for entry in ordered {
            groups[group(of: entry), default: []].append(entry)
        }
        return groups.keys.sorted().map { group in
            ConsoleListSection(id: group.id, title: group.title, entries: groups[group] ?? [])
        }
    }

    private nonisolated func group(of entry: PeekEntry) -> Group {
        switch self {
        case .status:
            // The code first: Dio reports every 4xx/5xx as a badResponse failure, and those belong with their code.
            if let code = entry.statusCode {
                let title = [String(code), PeekHTTPStatus.reasonPhrase(for: code)].compactMap(\.self).joined(separator: " ")
                return Group(rank: 0, code: code, title: title)
            }
            if let failure = entry.failure {
                return Group(rank: 1, code: PeekFailureKind.allCases.firstIndex(of: failure.kind) ?? 0, title: failure.kind.title)
            }
            return Group(rank: 2, code: 0, title: PeekEntryState.pending.title)
        case .host: return Group(rank: 0, code: 0, title: entry.request.host)
        case .source: return Group(rank: 0, code: 0, title: entry.source)
        case .none: return Group(rank: 0, code: 0, title: "")
        }
    }

    /// Titles come from the code, not the server's own status message, so "200 Success" doesn't split the 200s.
    private nonisolated struct Group: Hashable, Comparable {
        let rank: Int
        let code: Int
        let title: String

        var id: String { "\(rank)-\(code)-\(title)" }

        static func < (lhs: Group, rhs: Group) -> Bool {
            (lhs.rank, lhs.code, lhs.title) < (rhs.rank, rhs.code, rhs.title)
        }
    }
}
