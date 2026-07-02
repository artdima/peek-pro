import Foundation
import Testing
@testable import Peek_Pro

@Suite("List grouping")
struct ConsoleListGroupingTests {
    private typealias F = QueryFixtures

    private func layout(_ grouping: ConsoleListGrouping, _ entries: [PeekEntry] = F.all) -> [String] {
        grouping.sections(of: entries).map { section in
            "\(section.title ?? "-"): \(F.ids(section.entries).joined(separator: " "))"
        }
    }

    private func entry(_ id: String, second: Int, status: Int? = nil, message: String? = nil, failure: PeekFailureKind? = nil) -> PeekEntry {
        PeekEntry(
            id: PeekId(id),
            request: PeekRequest(method: "GET", uri: URL(string: "https://api.example.com/\(id)")!),
            startedAt: F.start.addingTimeInterval(TimeInterval(second)),
            source: "dio",
            response: status.map { PeekResponse(statusCode: $0, statusMessage: message) },
            failure: failure.map { PeekFailure(kind: $0, message: "failed") },
            completedAt: F.start.addingTimeInterval(TimeInterval(second) + 1)
        )
    }

    @Test("status: codes, then failures, then pending")
    func status() {
        #expect(layout(.status) == [
            "200 OK: e1 e3",
            "401 Unauthorized: e2",
            "503 Service Unavailable: e6",
            "Timed out: e5",
            "Pending: e4",
        ])
    }

    @Test("status: a code stays one section whatever the server calls it")
    func statusMessage() {
        let entries = [entry("a", second: 0, status: 200), entry("b", second: 1, status: 200, message: "Success")]
        #expect(layout(.status, entries) == ["200 OK: a b"])
    }

    @Test("status: a failure with a response goes under its code")
    func badResponse() {
        let entries = [
            entry("a", second: 0, status: 500, failure: .badResponse),
            entry("b", second: 1, failure: .connection),
            entry("c", second: 2, failure: .timeout),
        ]
        #expect(layout(.status, entries) == ["500 Internal Server Error: a", "Timed out: c", "Connection failed: b"])
    }

    @Test("oldest first inside a section")
    func oldestFirst() {
        #expect(layout(.status, F.all.reversed()) == layout(.status))
        #expect(layout(.none, F.all.reversed()) == ["-: e1 e2 e3 e4 e5 e6"])
    }

    @Test("host and source sections go by name")
    func names() {
        #expect(layout(.host) == ["api.example.com: e1 e2 e4 e5", "cdn.example.com: e3", "other.example.com: e6"])
        #expect(layout(.source) == ["dio: e1 e2 e3 e6", "talker: e4 e5"])
    }

    @Test("no sections for no entries")
    func empty() {
        #expect(ConsoleListGrouping.status.sections(of: []).isEmpty)
        #expect(layout(.none, []) == ["-: "])
    }
}
