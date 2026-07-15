import Foundation
import Testing
@testable import Peek_Pro

private let start = QueryFixtures.start

private func call(_ index: Int, method: String = "GET", status: Int? = 200, pinned: Bool = false) -> PeekEntry {
    let startedAt = start.addingTimeInterval(TimeInterval(index))
    return PeekEntry(
        id: PeekId("c\(index)"),
        request: PeekRequest(method: method, uri: URL(string: "https://api.example.com/items/\(index)")!),
        startedAt: startedAt,
        source: "dio",
        response: status.map { PeekResponse(statusCode: $0) },
        completedAt: status == nil ? nil : startedAt.addingTimeInterval(0.1),
        isPinned: pinned
    )
}

@Suite("Store journal")
struct SessionStoreJournalTests {
    @Test("reports appended and replaced positions since a revision")
    func changes() {
        var store = SessionStore(entries: [call(0), call(1)])
        let base = store.revision
        #expect(store.changedPositions(since: base) == [])
        store.upsert(call(2))
        store.upsert(call(0, status: 500))
        store.setPinned([PeekId("c1")], to: true)
        #expect(store.changedPositions(since: base) == [0, 1, 2])
        let later = store.revision
        store.upsert(call(3))
        #expect(store.changedPositions(since: later) == [3])
    }

    @Test("can't answer across a removal, a clear or a revision it never had")
    func gaps() {
        var store = SessionStore(entries: [call(0), call(1)])
        let base = store.revision
        store.remove(PeekId("c0"))
        #expect(store.changedPositions(since: base) == nil)
        #expect(store.changedPositions(since: store.revision) == [])
        #expect(store.changedPositions(since: store.revision + 1) == nil)
        let beforeClear = store.revision
        store.clear()
        #expect(store.changedPositions(since: beforeClear) == nil)
    }

    @Test("forgets the oldest changes past its limit")
    func overflow() {
        var store = SessionStore()
        let base = store.revision
        for index in 0..<(SessionStore.journalLimit + 10) { store.upsert(call(index)) }
        #expect(store.changedPositions(since: base) == nil)
        let recent = store.revision - 5
        #expect(store.changedPositions(since: recent)?.count == 5)
    }

    @Test("an eviction counts as a removal")
    func eviction() {
        var store = SessionStore(limit: 2, entries: [call(0), call(1)])
        let base = store.revision
        store.upsert(call(2))
        #expect(store.changedPositions(since: base) == nil)
    }

    @Test("keeps the latest start and tells stores apart")
    func latestStart() {
        var store = SessionStore(entries: [call(3), call(1)])
        #expect(store.latestStart == start.addingTimeInterval(3))
        store.upsert(call(5))
        #expect(store.latestStart == start.addingTimeInterval(5))
        store.remove(PeekId("c5"))
        #expect(store.latestStart == start.addingTimeInterval(3))
        store.clear()
        #expect(store.latestStart == nil)
        #expect(SessionStore().instance != SessionStore().instance)
    }
}

@Suite("Console selection")
struct ConsoleSelectionTests {
    private let errors = PeekFilter(onlyErrors: true)

    private func expectMatchesFullFilter(_ selection: ConsoleSelection, _ store: SessionStore, _ filter: PeekFilter) {
        #expect(selection.entries == filter.apply(store.entries))
    }

    @Test("updates in place on appends and replacements")
    func incremental() {
        var store = SessionStore(entries: (0..<10).map { call($0, status: $0 % 3 == 0 ? 500 : 200) })
        var selection = ConsoleSelection()
        selection.update(from: store, filter: errors)
        #expect(selection.lastUpdate == .full)
        let generation = selection.generation

        selection.update(from: store, filter: errors)
        #expect(selection.lastUpdate == .unchanged)
        #expect(selection.generation == generation)

        store.upsert(call(10, status: 200))
        selection.update(from: store, filter: errors)
        #expect(selection.lastUpdate == .incremental)
        #expect(selection.generation == generation)

        store.upsert(call(11, status: 404))
        store.upsert(call(1, status: 503))
        store.upsert(call(3, status: 200))
        selection.update(from: store, filter: errors)
        #expect(selection.lastUpdate == .incremental)
        #expect(selection.generation == generation + 1)
        #expect(selection.entries.map(\.id.value) == ["c0", "c1", "c6", "c9", "c11"])
        expectMatchesFullFilter(selection, store, errors)
    }

    @Test("starts over on a removal, a new filter or another store")
    func fullRebuilds() {
        var store = SessionStore(entries: (0..<5).map { call($0) })
        var selection = ConsoleSelection()
        selection.update(from: store, filter: .none)
        store.remove(PeekId("c2"))
        selection.update(from: store, filter: .none)
        #expect(selection.lastUpdate == .full)
        expectMatchesFullFilter(selection, store, .none)

        selection.update(from: store, filter: errors)
        #expect(selection.lastUpdate == .full)
        #expect(selection.entries.isEmpty)

        let other = SessionStore(entries: [call(0, status: 500)])
        selection.update(from: other, filter: errors)
        #expect(selection.lastUpdate == .full)
        #expect(selection.entries.map(\.id.value) == ["c0"])

        selection.update(from: nil, filter: errors)
        #expect(selection.entries.isEmpty)
        let generation = selection.generation
        selection.update(from: nil, filter: errors)
        #expect(selection.generation == generation)
    }

    @Test("always agrees with filtering from scratch", arguments: [
        PeekFilter.none,
        PeekFilter(onlyErrors: true),
        PeekFilter(methods: ["POST"], onlyPinned: true),
        PeekFilter(states: [.pending]),
        PeekFilter(query: PeekSearchQuery("items/1")),
    ])
    func agreesWithFullFilter(_ filter: PeekFilter) {
        var random = SplitMix(seed: 42)
        var store = SessionStore(limit: 300)
        var selection = ConsoleSelection()
        var next = 0
        let statuses: [Int?] = [nil, 200, 201, 404, 500]
        for _ in 0..<2_000 {
            switch random.next(100) {
            case 0..<55:
                store.upsert(call(next, method: random.next(3) == 0 ? "POST" : "GET", status: statuses[random.next(5)]))
                next += 1
            case 55..<85 where next > 0:
                store.upsert(call(random.next(next), status: statuses[random.next(5)]))
            case 85..<95 where next > 0:
                store.setPinned([PeekId("c\(random.next(next))")], to: random.next(2) == 0)
            default:
                if let entry = store.entries.randomElement(using: &random) { store.remove(entry.id) }
            }
            selection.update(from: store, filter: filter)
            #expect(selection.entries == filter.apply(store.entries))
        }
    }

    @Test("keeps a live 100k session cheap to update")
    func performance() {
        var store = SessionStore(entries: (0..<100_000).map { call($0, method: $0 % 7 == 0 ? "POST" : "GET", status: $0 % 11 == 0 ? 500 : 200) })
        let filter = PeekFilter(onlyErrors: true, query: PeekSearchQuery("items"))
        var selection = ConsoleSelection()
        let clock = ContinuousClock()
        let full = clock.measure { selection.update(from: store, filter: filter) }
        store.remove(PeekId("c0"))
        selection.update(from: store, filter: filter)
        store.upsert(call(100_001, status: 500))
        store.upsert(call(50, status: 500))
        let incremental = clock.measure { selection.update(from: store, filter: filter) }
        print("ConsoleSelection at 100k: full \(full), incremental \(incremental)")
        #expect(selection.lastUpdate == .incremental)
        #expect(incremental < full)
        #expect(selection.entries == filter.apply(store.entries))
    }
}

/// Deterministic, so a failing sequence can be replayed.
private struct SplitMix: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(_ bound: Int) -> Int {
        Int(next(upperBound: UInt64(bound)))
    }
}
