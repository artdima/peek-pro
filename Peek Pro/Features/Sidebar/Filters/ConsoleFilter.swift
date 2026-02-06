import Foundation

/// Mirrors `PeekFilter` from Peek core; on mocks it filters the fixture array directly.
nonisolated struct ConsoleFilter: Equatable, Sendable {
    nonisolated enum TimeWindow: Int, CaseIterable, Identifiable, Sendable {
        case any = 0
        case last5 = 5
        case last15 = 15
        case last60 = 60

        var id: Self { self }

        var title: String {
            switch self {
            case .any: "Any Time"
            case .last5: "Last 5 Minutes"
            case .last15: "Last 15 Minutes"
            case .last60: "Last Hour"
            }
        }
    }

    var statusClasses: Set<PeekStatusClass> = []
    var statusCodes: Set<Int> = []
    var methods: Set<String> = []
    var hosts: Set<String> = []
    var contentTypes: Set<String> = []
    var states: Set<PeekEntryState> = []
    var sources: Set<String> = []
    var onlyPinned = false
    /// Milliseconds.
    var minDuration: Double?
    var maxDuration: Double?
    var timeWindow: TimeWindow = .any

    var activeCount: Int {
        let sets = [
            statusClasses.isEmpty, statusCodes.isEmpty, methods.isEmpty, hosts.isEmpty,
            contentTypes.isEmpty, states.isEmpty, sources.isEmpty,
        ].filter { !$0 }.count
        let duration = minDuration != nil || maxDuration != nil ? 1 : 0
        return sets + duration + (onlyPinned ? 1 : 0) + (timeWindow == .any ? 0 : 1)
    }

    var isEmpty: Bool { activeCount == 0 }

    func apply(_ entries: [PeekEntry]) -> [PeekEntry] {
        guard !isEmpty else { return entries }
        let latest = timeWindow == .any ? nil : entries.map(\.startedAt).max()
        return entries.filter { matches($0, latest: latest) }
    }

    /// The time window counts back from the latest request, so a file from last week still filters sensibly.
    func matches(_ entry: PeekEntry, latest: Date?) -> Bool {
        if !statusClasses.isEmpty {
            guard let statusClass = entry.statusClass, statusClasses.contains(statusClass) else { return false }
        }
        if !statusCodes.isEmpty {
            guard let code = entry.statusCode, statusCodes.contains(code) else { return false }
        }
        if !methods.isEmpty, !methods.contains(entry.request.method) { return false }
        if !hosts.isEmpty, !hosts.contains(entry.request.host) { return false }
        if !contentTypes.isEmpty {
            guard let type = entry.contentTypeKey, contentTypes.contains(type) else { return false }
        }
        if !states.isEmpty, !states.contains(entry.state) { return false }
        if !sources.isEmpty, !sources.contains(entry.source) { return false }
        if onlyPinned, !entry.isPinned { return false }
        if minDuration != nil || maxDuration != nil {
            guard let duration = entry.duration?.timeInterval else { return false }
            let milliseconds = duration * 1_000
            if let minDuration, milliseconds < minDuration { return false }
            if let maxDuration, milliseconds > maxDuration { return false }
        }
        if let latest, timeWindow != .any {
            let from = latest.addingTimeInterval(-Double(timeWindow.rawValue) * 60)
            if entry.startedAt < from { return false }
        }
        return true
    }
}

nonisolated struct FacetValue<Value: Hashable & Sendable>: Identifiable, Sendable {
    let value: Value
    let count: Int

    var id: Value { value }
}

/// Values present in the session with how many requests carry each — what the filter offers.
nonisolated struct ConsoleFacets: Sendable {
    let statusClasses: [FacetValue<PeekStatusClass>]
    let statusCodes: [FacetValue<Int>]
    let methods: [FacetValue<String>]
    let hosts: [FacetValue<String>]
    let contentTypes: [FacetValue<String>]
    let states: [FacetValue<PeekEntryState>]
    let sources: [FacetValue<String>]

    init(_ entries: [PeekEntry]) {
        statusClasses = Self.count(entries) { $0.statusClass }
            .sorted { Self.order(of: $0.value) < Self.order(of: $1.value) }
        statusCodes = Self.count(entries) { $0.statusCode }.sorted { $0.value < $1.value }
        methods = Self.count(entries) { $0.request.method }.sorted(by: Self.byCount)
        hosts = Self.count(entries) { $0.request.host }.sorted(by: Self.byCount)
        contentTypes = Self.count(entries) { $0.contentTypeKey }.sorted(by: Self.byCount)
        states = Self.count(entries) { $0.state }
            .sorted { Self.order(of: $0.value) < Self.order(of: $1.value) }
        sources = Self.count(entries) { $0.source }.sorted(by: Self.byCount)
    }

    private static func count<Value: Hashable & Sendable>(_ entries: [PeekEntry], _ key: (PeekEntry) -> Value?) -> [FacetValue<Value>] {
        var counts: [Value: Int] = [:]
        for entry in entries {
            if let value = key(entry) { counts[value, default: 0] += 1 }
        }
        return counts.map { FacetValue(value: $0.key, count: $0.value) }
    }

    private static func byCount(_ lhs: FacetValue<String>, _ rhs: FacetValue<String>) -> Bool {
        lhs.count == rhs.count ? lhs.value < rhs.value : lhs.count > rhs.count
    }

    private static func order<Value: CaseIterable & Equatable>(of value: Value) -> Int {
        Array(Value.allCases).firstIndex(of: value) ?? 0
    }
}

extension PeekEntry {
    nonisolated var contentTypeKey: String? {
        (response?.mediaType ?? request.mediaType)?.mimeType
    }
}

nonisolated extension Set {
    /// Lets a checkbox bind straight to membership: `$filter.methods[contains: "GET"]`.
    subscript(contains element: Element) -> Bool {
        get { contains(element) }
        set {
            if newValue { insert(element) } else { remove(element) }
        }
    }
}
