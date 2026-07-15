import Foundation

/// The entries of one session that pass a filter, kept up to date incrementally: after the store changes,
/// only the entries it appended or replaced are matched again. A removal, another filter or another store
/// starts over — at 100k entries a live session would otherwise re-filter everything several times a second.
nonisolated struct ConsoleSelection {
    enum Update: Equatable {
        case unchanged
        case incremental
        case full
    }

    /// In the store's order.
    private(set) var entries: [PeekEntry] = []
    /// Bumped whenever `entries` changes, for whatever is derived from them.
    private(set) var generation = 0
    private(set) var lastUpdate = Update.full

    /// Store positions of `entries`, ascending.
    private var positions: [Int] = []
    private var filter: PeekFilter?
    private var matcher: (@Sendable (PeekEntry) -> Bool)?
    private var storeInstance: UUID?
    private var revision = -1

    mutating func update(from store: SessionStore?, filter: PeekFilter) {
        guard let store else {
            if storeInstance != nil || self.filter != filter || generation == 0 {
                reset(entries: [], positions: [], instance: nil, revision: -1, filter: filter, matcher: nil)
            } else {
                lastUpdate = .unchanged
            }
            return
        }
        if filter == self.filter, store.instance == storeInstance, let matcher {
            if store.revision == revision {
                lastUpdate = .unchanged
                return
            }
            if let changed = store.changedPositions(since: revision) {
                apply(changed, from: store, matcher: matcher)
                revision = store.revision
                lastUpdate = .incremental
                return
            }
        }
        let matcher = filter.compile()
        var entries: [PeekEntry] = []
        var positions: [Int] = []
        for (position, entry) in store.entries.enumerated() where matcher(entry) {
            entries.append(entry)
            positions.append(position)
        }
        reset(entries: entries, positions: positions, instance: store.instance, revision: store.revision, filter: filter, matcher: matcher)
    }

    private mutating func apply(_ changed: [Int], from store: SessionStore, matcher: (PeekEntry) -> Bool) {
        var didChange = false
        for position in changed {
            let entry = store.entries[position]
            let matches = matcher(entry)
            let index = positions.partitioningIndex { $0 < position }
            let present = index < positions.count && positions[index] == position
            switch (present, matches) {
            case (true, true):
                entries[index] = entry
            case (true, false):
                positions.remove(at: index)
                entries.remove(at: index)
            case (false, true):
                positions.insert(position, at: index)
                entries.insert(entry, at: index)
            case (false, false):
                continue
            }
            didChange = true
        }
        if didChange { generation += 1 }
    }

    private mutating func reset(
        entries: [PeekEntry],
        positions: [Int],
        instance: UUID?,
        revision: Int,
        filter: PeekFilter,
        matcher: (@Sendable (PeekEntry) -> Bool)?
    ) {
        self.entries = entries
        self.positions = positions
        storeInstance = instance
        self.revision = revision
        self.filter = filter
        self.matcher = matcher
        generation += 1
        lastUpdate = .full
    }
}
