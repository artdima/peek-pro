import Foundation
import Testing
@testable import Peek_Pro

@Suite("Table sort")
struct ConsoleSortTests {
    private typealias F = QueryFixtures

    private func order(_ column: ConsoleSortColumn, _ order: SortOrder = .forward, _ entries: [PeekEntry] = F.all) -> [String] {
        F.ids(ConsoleSort(column, order: order).apply(entries))
    }

    @Test("keeps missing values last in both directions")
    func missingLast() {
        #expect(order(.duration) == ["e3", "e1", "e2", "e6", "e5", "e4"])
        #expect(order(.duration, .reverse) == ["e5", "e6", "e2", "e1", "e3", "e4"])
        #expect(order(.status) == ["e1", "e3", "e2", "e6", "e4", "e5"])
        #expect(order(.status, .reverse) == ["e6", "e2", "e1", "e3", "e4", "e5"])
    }

    @Test("sorts text columns and keeps ties in arrival order")
    func text() {
        #expect(order(.method) == ["e5", "e1", "e3", "e4", "e6", "e2"])
        #expect(order(.source, .reverse) == ["e4", "e5", "e1", "e2", "e3", "e6"])
        #expect(order(.url) == ["e2", "e4", "e1", "e5", "e3", "e6"])
    }

    @Test("puts pinned entries first on the first click")
    func pinned() {
        #expect(order(.pinned) == ["e5", "e1", "e2", "e3", "e4", "e6"])
        #expect(order(.pinned, .reverse) == ["e1", "e2", "e3", "e4", "e6", "e5"])
    }

    @Test("sorts by start oldest first by default")
    func defaultOrder() {
        #expect(ConsoleSort.default == ConsoleSort(.startedAt, order: .forward))
        #expect(F.ids(ConsoleSort.default.apply(F.all.reversed())) == F.ids(F.all))
        #expect(order(.startedAt, .reverse) == ["e6", "e5", "e4", "e3", "e2", "e1"])
    }

    @Test("round-trips through scene storage")
    func storage() {
        for column in ConsoleSortColumn.allCases {
            for direction in [SortOrder.forward, .reverse] {
                let sort = ConsoleSort(column, order: direction)
                #expect(ConsoleSort(storage: sort.storage) == sort)
            }
        }
        #expect(ConsoleSort(storage: "") == nil)
        #expect(ConsoleSort(storage: "size:forward") == nil)
        #expect(ConsoleSort(storage: "duration:up") == nil)
    }
}
