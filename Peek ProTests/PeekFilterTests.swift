import Foundation
import Testing
@testable import Peek_Pro

@Suite("Filter")
struct PeekFilterTests {
    private typealias F = QueryFixtures

    private func keep(_ filter: PeekFilter) -> [String] {
        F.ids(filter.apply(F.all))
    }

    @Test("matches everything by default")
    func none() {
        #expect(PeekFilter.none.isEmpty)
        #expect(PeekFilter.none.activeCount == 0)
        #expect(keep(PeekFilter.none) == F.ids(F.all))
    }

    @Test("filters by method, ignoring case")
    func methods() {
        #expect(keep(PeekFilter(methods: ["post"])) == ["e2"])
        #expect(keep(PeekFilter(methods: ["GET", "delete"])) == ["e1", "e3", "e4", "e5", "e6"])
    }

    @Test("filters by host, ignoring case")
    func hosts() {
        #expect(keep(PeekFilter(hosts: ["CDN.example.com"])) == ["e3"])
        #expect(keep(PeekFilter(hosts: ["other.example.com"])) == ["e6"])
    }

    @Test("filters by status class and code")
    func status() {
        #expect(keep(PeekFilter(statusClasses: [.success])) == ["e1", "e3"])
        #expect(keep(PeekFilter(statusClasses: [.clientError, .serverError])) == ["e2", "e6"])
        #expect(keep(PeekFilter(statusCodes: [200, 503])) == ["e1", "e3", "e6"])
    }

    @Test("drops entries without a status when status is filtered")
    func noStatus() {
        #expect(keep(PeekFilter(statusClasses: [.unknown])).isEmpty)
        #expect(keep(PeekFilter(statusCodes: [0])).isEmpty)
    }

    @Test("filters by state, source and pin")
    func stateSourcePin() {
        #expect(keep(PeekFilter(states: [.pending])) == ["e4"])
        #expect(keep(PeekFilter(states: [.completed, .failed])) == ["e1", "e2", "e3", "e5", "e6"])
        #expect(keep(PeekFilter(sources: ["talker"])) == ["e4", "e5"])
        #expect(keep(PeekFilter(onlyPinned: true)) == ["e5"])
    }

    @Test("filters errors: failures and 4xx/5xx")
    func errors() {
        #expect(keep(PeekFilter(onlyErrors: true)) == ["e2", "e5", "e6"])
    }

    @Test("filters by response media type without parameters")
    func contentTypes() {
        #expect(keep(PeekFilter(contentTypes: ["application/json"])) == ["e1", "e2"])
        #expect(keep(PeekFilter(contentTypes: ["IMAGE/PNG"])) == ["e3"])
    }

    @Test("filters by duration and leaves pending calls out")
    func duration() {
        #expect(keep(PeekFilter(duration: PeekDurationRange(min: .milliseconds(300)))) == ["e2", "e5", "e6"])
        #expect(keep(PeekFilter(duration: PeekDurationRange(min: .milliseconds(100), max: .milliseconds(300)))) == ["e1", "e2"])
        #expect(keep(PeekFilter(duration: PeekDurationRange(max: .milliseconds(50)))) == ["e3"])
    }

    @Test("filters by start time, bounds included")
    func dates() {
        let from = F.start.addingTimeInterval(2)
        let to = F.start.addingTimeInterval(4)
        #expect(keep(PeekFilter(dates: PeekDateRange(from: from, to: to))) == ["e3", "e4", "e5"])
        #expect(keep(PeekFilter(dates: PeekDateRange(from: to))) == ["e5", "e6"])
        #expect(keep(PeekFilter(dates: PeekDateRange(to: from))) == ["e1", "e2", "e3"])
    }

    @Test("searches text as one more criterion")
    func search() {
        #expect(keep(PeekFilter(query: PeekSearchQuery("users"))) == ["e1", "e5"])
        #expect(keep(PeekFilter(onlyErrors: true, query: PeekSearchQuery("users"))) == ["e5"])
        var filter = PeekFilter(query: PeekSearchQuery("users"))
        #expect(filter.matches(F.e1))
        #expect(!filter.matches(F.e2))
        #expect(filter.activeCount == 1)
        #expect(filter != PeekFilter(query: PeekSearchQuery("x")))
        filter.query = PeekSearchQuery.none
        #expect(filter.isEmpty)
    }

    @Test("requires every set criterion to hold")
    func allCriteria() {
        var filter = PeekFilter(methods: ["GET"], hosts: ["api.example.com"], states: [.completed])
        #expect(keep(filter) == ["e1"])
        filter.onlyErrors = true
        #expect(keep(filter).isEmpty)
    }

    @Test("counts active criteria")
    func activeCount() {
        #expect(PeekFilter(methods: ["GET"]).activeCount == 1)
        let filter = PeekFilter(
            methods: ["GET"],
            hosts: ["a"],
            onlyErrors: true,
            duration: PeekDurationRange(max: .zero),
            dates: PeekDateRange(from: F.start)
        )
        #expect(filter.activeCount == 5)
        #expect(!PeekFilter(onlyPinned: true).isEmpty)
    }

    @Test("clears criteria with empty sets and open ranges")
    func clearing() {
        var filter = PeekFilter(methods: ["GET"], duration: PeekDurationRange(max: .zero), dates: PeekDateRange(from: F.start))
        filter.methods = []
        filter.duration = .any
        #expect(filter.activeCount == 1)
        filter.hosts = ["h"]
        #expect(filter.activeCount == 2)
        filter.hosts = []
        filter.dates = .any
        #expect(filter.isEmpty)
        #expect(filter == PeekFilter.none)
    }

    @Test("compares by value regardless of set order")
    func equality() {
        let one = PeekFilter(methods: ["GET", "POST"], statusCodes: [1, 2])
        let two = PeekFilter(methods: ["POST", "GET"], statusCodes: [2, 1])
        var pinned = one
        pinned.onlyPinned = true
        #expect(one == two)
        #expect(one.hashValue == two.hashValue)
        #expect(one != pinned)
        #expect(one.activeCount == 2)
    }

    @Test("ranges contain their bounds")
    func ranges() {
        let range = PeekDurationRange(min: .seconds(1), max: .seconds(2))
        #expect(range.contains(.seconds(1)))
        #expect(range.contains(.seconds(2)))
        #expect(!range.contains(.milliseconds(999)))
        #expect(!range.isUnbounded)
        #expect(PeekDurationRange.any.contains(.zero))
        #expect(range != PeekDurationRange.any)

        let dates = PeekDateRange(from: F.start, to: F.start)
        #expect(dates.contains(F.start))
        #expect(!dates.contains(F.start.addingTimeInterval(1)))
        #expect(dates == PeekDateRange(from: F.start, to: F.start))
        #expect(dates != PeekDateRange.any)
        #expect(PeekDateRange.any.isUnbounded)
    }
}
