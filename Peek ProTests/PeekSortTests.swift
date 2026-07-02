import Foundation
import Testing
@testable import Peek_Pro

@Suite("Sort")
struct PeekSortTests {
    private typealias F = QueryFixtures

    private func order(_ sort: PeekSort, _ entries: [PeekEntry] = F.all) -> [String] {
        F.ids(sort.apply(entries))
    }

    @Test("defaults to newest first")
    func defaults() {
        #expect(PeekSort.newestFirst.field == .startedAt)
        #expect(PeekSort.newestFirst.descending)
        #expect(order(.newestFirst) == ["e6", "e5", "e4", "e3", "e2", "e1"])
        #expect(order(.oldestFirst) == ["e1", "e2", "e3", "e4", "e5", "e6"])
    }

    @Test("orders by duration and puts pending calls last either way")
    func duration() {
        #expect(order(.slowestFirst) == ["e5", "e6", "e2", "e1", "e3", "e4"])
        #expect(order(PeekSort(field: .duration, descending: false)) == ["e3", "e1", "e2", "e6", "e5", "e4"])
    }

    @Test("orders by status code, calls without one last")
    func statusCode() {
        #expect(order(PeekSort(field: .statusCode)) == ["e6", "e2", "e1", "e3", "e4", "e5"])
        #expect(order(PeekSort(field: .statusCode, descending: false)) == ["e1", "e3", "e2", "e6", "e4", "e5"])
    }

    @Test("keeps the incoming order for equal keys")
    func stable() {
        #expect(order(.largestFirst) == ["e1", "e2", "e3", "e6", "e4", "e5"])
        #expect(order(PeekSort(field: .responseSize, descending: false)) == ["e1", "e2", "e3", "e6", "e4", "e5"])
        #expect(order(PeekSort(field: .requestSize)) == ["e1", "e2", "e3", "e4", "e5", "e6"])
        #expect(order(.largestFirst, F.all.reversed()) == ["e6", "e3", "e2", "e1", "e5", "e4"])
    }

    @Test("leaves the input alone")
    func input() {
        let input = [F.e2, F.e1]
        #expect(order(.oldestFirst, input) == ["e1", "e2"])
        #expect(F.ids(input) == ["e2", "e1"])
        #expect(PeekSort.oldestFirst.apply([]).isEmpty)
    }

    @Test("compares pairs consistently")
    func compare() {
        let sort = PeekSort.slowestFirst
        #expect(sort.compare(F.e5, F.e1) == .orderedAscending)
        #expect(sort.compare(F.e1, F.e5) == .orderedDescending)
        #expect(sort.compare(F.e1, F.e1) == .orderedSame)
        #expect(sort.compare(F.e4, F.e1) == .orderedDescending)
        #expect(sort.compare(F.e1, F.e4) == .orderedAscending)
        #expect(sort.compare(F.e4, F.e4) == .orderedSame)
    }

    @Test("compares by value")
    func equality() {
        var sort = PeekSort.newestFirst
        sort.field = .duration
        #expect(sort == .slowestFirst)
        #expect(sort.hashValue == PeekSort.slowestFirst.hashValue)
        sort.descending = false
        #expect(sort != .slowestFirst)
    }
}
