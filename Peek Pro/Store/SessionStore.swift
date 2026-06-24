import Foundation

/// The entries of one source — a device or a file — in the order they first arrived.
///
/// Bounded like `InMemoryPeekStore` in Peek: when full, adding an entry evicts the oldest unpinned
/// completed one, so calls in flight and pinned entries survive; only when nothing else is left
/// does the oldest pending, and last of all the oldest pinned, entry go.
nonisolated struct SessionStore: Sendable {
    static let defaultLimit = 100_000

    let limit: Int
    private(set) var entries: [PeekEntry] = []
    private var positions: [PeekId: Int] = [:]

    init(limit: Int = defaultLimit, entries: [PeekEntry] = []) {
        precondition(limit > 0, "SessionStore needs room for at least one entry")
        self.limit = limit
        upsert(contentsOf: entries)
    }

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    func entry(_ id: PeekId) -> PeekEntry? {
        positions[id].map { entries[$0] }
    }

    /// Replaces the entry with the same id in place, or appends it. Returns what was evicted to make room.
    @discardableResult
    mutating func upsert(_ entry: PeekEntry) -> PeekEntry? {
        if let position = positions[entry.id] {
            entries[position] = entry
            return nil
        }
        let evicted = entries.count >= limit ? evict() : nil
        positions[entry.id] = entries.count
        entries.append(entry)
        return evicted
    }

    mutating func upsert(contentsOf newEntries: some Sequence<PeekEntry>) {
        for entry in newEntries { upsert(entry) }
    }

    /// Changes the entry in place; `false` when there is no such entry.
    @discardableResult
    mutating func update(_ id: PeekId, _ change: (inout PeekEntry) -> Void) -> Bool {
        guard let position = positions[id] else { return false }
        change(&entries[position])
        return true
    }

    @discardableResult
    mutating func togglePin(_ id: PeekId) -> Bool {
        update(id) { $0.isPinned.toggle() }
    }

    @discardableResult
    mutating func remove(_ id: PeekId) -> PeekEntry? {
        guard let position = positions[id] else { return nil }
        return remove(at: position)
    }

    mutating func clear() {
        entries = []
        positions = [:]
    }

    private mutating func evict() -> PeekEntry {
        let position = entries.firstIndex { !$0.isPinned && $0.state != .pending }
            ?? entries.firstIndex { !$0.isPinned }
            ?? entries.startIndex
        return remove(at: position)
    }

    private mutating func remove(at position: Int) -> PeekEntry {
        let removed = entries.remove(at: position)
        positions[removed.id] = nil
        for index in position..<entries.count {
            positions[entries[index].id] = index
        }
        return removed
    }
}
