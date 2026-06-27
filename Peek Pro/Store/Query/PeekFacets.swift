import Foundation

nonisolated struct PeekFacet<Value: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    let value: Value
    let count: Int

    var id: Value { value }
}

/// Mirrors `PeekFacets` from Peek core: the values a filter can pick from, counted over a set of entries.
/// Every list is ranked by count, highest first, ties by value.
nonisolated struct PeekFacets: Sendable {
    static let empty = PeekFacets([])

    let total: Int
    let errors: Int
    let pinned: Int
    let methods: [PeekFacet<String>]
    let hosts: [PeekFacet<String>]
    let sources: [PeekFacet<String>]
    /// Response media types without parameters.
    let contentTypes: [PeekFacet<String>]
    let statusCodes: [PeekFacet<Int>]
    let statusClasses: [PeekFacet<PeekStatusClass>]
    let states: [PeekFacet<PeekEntryState>]

    init(_ entries: [PeekEntry]) {
        var total = 0
        var errors = 0
        var pinned = 0
        var methods: [String: Int] = [:]
        var hosts: [String: Int] = [:]
        var sources: [String: Int] = [:]
        var contentTypes: [String: Int] = [:]
        var statusCodes: [Int: Int] = [:]
        var statusClasses: [PeekStatusClass: Int] = [:]
        var states: [PeekEntryState: Int] = [:]

        for entry in entries {
            total += 1
            if entry.isError { errors += 1 }
            if entry.isPinned { pinned += 1 }
            methods[entry.request.method, default: 0] += 1
            hosts[entry.request.host, default: 0] += 1
            sources[entry.source, default: 0] += 1
            states[entry.state, default: 0] += 1
            if let type = entry.response?.mediaType?.mimeType { contentTypes[type, default: 0] += 1 }
            if let code = entry.statusCode { statusCodes[code, default: 0] += 1 }
            if let statusClass = entry.statusClass { statusClasses[statusClass, default: 0] += 1 }
        }

        self.total = total
        self.errors = errors
        self.pinned = pinned
        self.methods = Self.ranked(methods, by: <)
        self.hosts = Self.ranked(hosts, by: <)
        self.sources = Self.ranked(sources, by: <)
        self.contentTypes = Self.ranked(contentTypes, by: <)
        self.statusCodes = Self.ranked(statusCodes, by: <)
        self.statusClasses = Self.ranked(statusClasses, by: Self.caseOrder)
        self.states = Self.ranked(states, by: Self.caseOrder)
    }

    private static func ranked<Value: Hashable & Sendable>(_ counts: [Value: Int], by precedes: (Value, Value) -> Bool) -> [PeekFacet<Value>] {
        counts
            .map { PeekFacet(value: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? precedes($0.value, $1.value) : $0.count > $1.count }
    }

    private static func caseOrder<Value: CaseIterable & Equatable>(_ lhs: Value, _ rhs: Value) -> Bool {
        let cases = Array(Value.allCases)
        return (cases.firstIndex(of: lhs) ?? 0) < (cases.firstIndex(of: rhs) ?? 0)
    }
}
