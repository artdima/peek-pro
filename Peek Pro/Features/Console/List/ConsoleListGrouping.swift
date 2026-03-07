import Foundation

enum ConsoleListGrouping: String, CaseIterable, Identifiable {
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

struct ConsoleListSection: Identifiable {
    let id: String
    let title: String?
    let entries: [PeekEntry]
}

extension ConsoleListGrouping {
    /// Oldest first inside a section; status sections go by code, then failures, then pending — as Pulse orders them.
    func sections(of entries: [PeekEntry]) -> [ConsoleListSection] {
        let ordered = entries.sorted { $0.startedAt < $1.startedAt }
        guard self != .none else {
            return [ConsoleListSection(id: "all", title: nil, entries: ordered)]
        }
        var keys: [String] = []
        var groups: [String: [PeekEntry]] = [:]
        for entry in ordered {
            let groupKey = key(for: entry)
            if groups[groupKey] == nil { keys.append(groupKey) }
            groups[groupKey, default: []].append(entry)
        }
        let sortedKeys = keys.sorted { lhs, rhs in
            let left = rank(of: groups[lhs]?.first)
            let right = rank(of: groups[rhs]?.first)
            return left == right ? lhs < rhs : left < right
        }
        return sortedKeys.map { key in
            ConsoleListSection(id: key, title: key, entries: groups[key] ?? [])
        }
    }

    private func key(for entry: PeekEntry) -> String {
        switch self {
        case .status: entry.statusTitle
        case .host: entry.request.host
        case .source: entry.source
        case .none: ""
        }
    }

    private func rank(of entry: PeekEntry?) -> Int {
        guard self == .status, let entry else { return 0 }
        if let code = entry.statusCode, entry.failure == nil { return code }
        if let failure = entry.failure {
            return 1_000 + (PeekFailureKind.allCases.firstIndex(of: failure.kind) ?? 0)
        }
        return 2_000
    }
}
