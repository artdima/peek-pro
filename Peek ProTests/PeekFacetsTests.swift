import Foundation
import Testing
@testable import Peek_Pro

@Suite("Facets")
struct PeekFacetsTests {
    private func facets<Value: Hashable & Sendable>(_ pairs: [(Value, Int)]) -> [PeekFacet<Value>] {
        pairs.map { PeekFacet(value: $0.0, count: $0.1) }
    }

    @Test("counts totals, errors and pins")
    func totals() {
        let facets = PeekFacets(QueryFixtures.all)
        #expect(facets.total == 6)
        #expect(facets.errors == 3)
        #expect(facets.pinned == 1)
    }

    @Test("ranks values by count, then by value")
    func ranking() {
        let facets = PeekFacets(QueryFixtures.all)
        #expect(facets.methods == self.facets([("GET", 4), ("DELETE", 1), ("POST", 1)]))
        #expect(facets.hosts == self.facets([("api.example.com", 4), ("cdn.example.com", 1), ("other.example.com", 1)]))
        #expect(facets.sources == self.facets([("dio", 4), ("talker", 2)]))
        #expect(facets.contentTypes == self.facets([("application/json", 2), ("image/png", 1), ("text/plain", 1)]))
        #expect(facets.statusCodes == self.facets([(200, 2), (401, 1), (503, 1)]))
        #expect(facets.statusClasses == self.facets([(PeekStatusClass.success, 2), (PeekStatusClass.clientError, 1), (PeekStatusClass.serverError, 1)]))
        #expect(facets.states == self.facets([(PeekEntryState.completed, 4), (PeekEntryState.pending, 1), (PeekEntryState.failed, 1)]))
    }

    @Test("is empty for no entries")
    func empty() {
        let facets = PeekFacets([])
        #expect(facets.total == 0)
        #expect(facets.methods.isEmpty)
        #expect(facets.statusClasses.isEmpty)
        #expect(PeekFacets.empty.total == 0)
        #expect(PeekFacets.empty.hosts.isEmpty)
    }
}
