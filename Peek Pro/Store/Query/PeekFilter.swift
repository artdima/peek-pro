import Foundation

nonisolated struct PeekDurationRange: Hashable, Sendable {
    static let any = PeekDurationRange()

    var min: Duration?
    var max: Duration?

    init(min: Duration? = nil, max: Duration? = nil) {
        self.min = min
        self.max = max
    }

    var isUnbounded: Bool { min == nil && max == nil }

    /// Bounds included.
    func contains(_ duration: Duration) -> Bool {
        if let min, duration < min { return false }
        if let max, duration > max { return false }
        return true
    }
}

nonisolated struct PeekDateRange: Hashable, Sendable {
    static let any = PeekDateRange()

    var from: Date?
    var to: Date?

    init(from: Date? = nil, to: Date? = nil) {
        self.from = from
        self.to = to
    }

    var isUnbounded: Bool { from == nil && to == nil }

    /// Bounds included.
    func contains(_ moment: Date) -> Bool {
        if let from, moment < from { return false }
        if let to, moment > to { return false }
        return true
    }
}

/// Mirrors `PeekFilter` from Peek core. Every criterion that is set must hold; an empty set,
/// an unbounded range or an empty `query` means "any". Methods, hosts and content types match case-insensitively.
nonisolated struct PeekFilter: Hashable, Sendable {
    static let none = PeekFilter()

    var methods: Set<String> = []
    var statusClasses: Set<PeekStatusClass> = []
    var statusCodes: Set<Int> = []
    var hosts: Set<String> = []
    var states: Set<PeekEntryState> = []
    var sources: Set<String> = []
    /// Bare response media types such as `application/json`.
    var contentTypes: Set<String> = []
    var onlyErrors = false
    var onlyPinned = false
    /// Only completed calls have a duration, so a bounded range leaves pending ones out.
    var duration = PeekDurationRange.any
    var dates = PeekDateRange.any
    var query = PeekSearchQuery.none

    var activeCount: Int {
        [
            !methods.isEmpty, !statusClasses.isEmpty, !statusCodes.isEmpty, !hosts.isEmpty,
            !states.isEmpty, !sources.isEmpty, !contentTypes.isEmpty, onlyErrors, onlyPinned,
            !duration.isUnbounded, !dates.isUnbounded, !query.isEmpty,
        ].count { $0 }
    }

    var isEmpty: Bool { activeCount == 0 }

    func matches(_ entry: PeekEntry) -> Bool { compile()(entry) }

    func apply(_ entries: [PeekEntry]) -> [PeekEntry] {
        guard !isEmpty else { return entries }
        let matcher = compile()
        return entries.filter(matcher)
    }

    /// Builds the matcher once; use it to test many entries.
    func compile() -> @Sendable (PeekEntry) -> Bool {
        let filter = self
        let methods = Set(self.methods.map { $0.uppercased() })
        let hosts = Set(self.hosts.map { $0.lowercased() })
        let contentTypes = Set(self.contentTypes.map { $0.lowercased() })
        let search = query.compile()
        return { entry in
            if filter.onlyErrors, !entry.isError { return false }
            if filter.onlyPinned, !entry.isPinned { return false }
            if !methods.isEmpty, !methods.contains(entry.request.method.uppercased()) { return false }
            if !hosts.isEmpty, !hosts.contains(entry.request.host.lowercased()) { return false }
            if !filter.states.isEmpty, !filter.states.contains(entry.state) { return false }
            if !filter.sources.isEmpty, !filter.sources.contains(entry.source) { return false }
            if !filter.statusClasses.isEmpty {
                guard let statusClass = entry.statusClass, filter.statusClasses.contains(statusClass) else { return false }
            }
            if !filter.statusCodes.isEmpty {
                guard let code = entry.statusCode, filter.statusCodes.contains(code) else { return false }
            }
            if !contentTypes.isEmpty {
                guard let type = entry.response?.mediaType?.mimeType, contentTypes.contains(type) else { return false }
            }
            if !filter.duration.isUnbounded {
                guard let duration = entry.duration, filter.duration.contains(duration) else { return false }
            }
            if !filter.dates.isUnbounded, !filter.dates.contains(entry.startedAt) { return false }
            return search(entry)
        }
    }
}
