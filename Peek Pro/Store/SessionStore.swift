import Foundation

/// The entries of one source — a device or a file — in the order they first arrived.
///
/// Bounded like `InMemoryPeekStore` in Peek: when full, adding an entry evicts the oldest unpinned
/// completed one, so calls in flight and pinned entries survive; only when nothing else is left
/// does the oldest pending, and last of all the oldest pinned, entry go.
nonisolated struct SessionStore: Sendable {
    static let defaultLimit = 100_000

    static let journalLimit = 4_096

    let limit: Int
    /// Tells a replaced store from the one before it, whose revisions it would otherwise repeat.
    let instance = UUID()
    private(set) var entries: [PeekEntry] = []
    private var positions: [PeekId: Int] = [:]
    /// Bumped on every change, so a view of the entries can tell whether it is stale.
    private(set) var revision = 0
    private(set) var latestStart: Date?
    /// Positions written since `journalStart`; positions hold still while entries are only appended or replaced.
    private var journal: [(revision: Int, position: Int)] = []
    private var journalStart = 0

    init(limit: Int = defaultLimit, entries: [PeekEntry] = []) {
        precondition(limit > 0, "SessionStore needs room for at least one entry")
        self.limit = limit
        upsert(contentsOf: entries)
        forgetJournal()
    }

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    func entry(_ id: PeekId) -> PeekEntry? {
        positions[id].map { entries[$0] }
    }

    func position(of id: PeekId) -> Int? {
        positions[id]
    }

    /// Positions appended or replaced after `revision`, ascending; `nil` when something was removed
    /// since then, or the journal no longer reaches back that far — start over from `entries`.
    func changedPositions(since revision: Int) -> [Int]? {
        guard revision >= journalStart, revision <= self.revision else { return nil }
        let first = journal.partitioningIndex { $0.revision <= revision }
        return Array(Set(journal[first...].map(\.position))).sorted()
    }

    /// Replaces the entry with the same id in place, or appends it. Returns what was evicted to make room.
    /// A replaced entry keeps the pin it has here: pins are the viewer's, and the source only says what the call did.
    @discardableResult
    mutating func upsert(_ entry: PeekEntry) -> PeekEntry? {
        if let position = positions[entry.id] {
            var entry = entry
            entry.isPinned = entries[position].isPinned
            entries[position] = entry
            noteChange(at: position, started: entry.startedAt)
            return nil
        }
        let evicted = entries.count >= limit ? evict() : nil
        positions[entry.id] = entries.count
        entries.append(entry)
        noteChange(at: entries.count - 1, started: entry.startedAt)
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
        noteChange(at: position, started: entries[position].startedAt)
        return true
    }

    /// Returns how many entries changed; ids that aren't here are skipped.
    @discardableResult
    mutating func setPinned(_ ids: some Sequence<PeekId>, to isPinned: Bool) -> Int {
        var changed = 0
        for id in ids {
            update(id) { entry in
                guard entry.isPinned != isPinned else { return }
                entry.isPinned = isPinned
                changed += 1
            }
        }
        return changed
    }

    @discardableResult
    mutating func remove(_ id: PeekId) -> PeekEntry? {
        guard let position = positions[id] else { return nil }
        return remove(at: position)
    }

    mutating func clear() {
        entries = []
        positions = [:]
        latestStart = nil
        forgetJournal()
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
        if removed.startedAt == latestStart { latestStart = entries.lazy.map(\.startedAt).max() }
        forgetJournal()
        return removed
    }

    private mutating func noteChange(at position: Int, started: Date) {
        revision += 1
        if latestStart.map({ started > $0 }) ?? true { latestStart = started }
        journal.append((revision, position))
        if journal.count > Self.journalLimit {
            let dropped = journal.count - Self.journalLimit / 2
            journalStart = journal[dropped - 1].revision
            journal.removeFirst(dropped)
        }
    }

    /// Positions moved, so nothing before now can be answered from the journal.
    private mutating func forgetJournal() {
        revision += 1
        journal = []
        journalStart = revision
    }
}
