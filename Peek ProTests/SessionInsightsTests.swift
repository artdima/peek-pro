import Foundation
import Testing
@testable import Peek_Pro

/// A call built in one line, for the Issues and Insights tests.
private func call(
    _ id: String,
    _ method: String = "GET",
    _ path: String = "/items",
    second: Int = 0,
    status: Int? = nil,
    failure: PeekFailureKind? = nil,
    ms: Int? = 100
) -> PeekEntry {
    let start = QueryFixtures.start.addingTimeInterval(TimeInterval(second))
    return PeekEntry(
        id: PeekId(id),
        request: PeekRequest(method: method, uri: URL(string: "https://api.example.com\(path)")!),
        startedAt: start,
        source: "dio",
        response: status.map { PeekResponse(statusCode: $0) },
        failure: failure.map { PeekFailure(kind: $0, message: "failed") },
        completedAt: ms.map { start.addingTimeInterval(TimeInterval($0) / 1_000) }
    )
}

@Suite("Issues")
struct SessionIssueTests {
    private func summary(_ issues: [SessionIssue]) -> [String] {
        issues.map { "\($0.title) · \($0.subtitle) · \($0.entryIDs.map(\.value).joined(separator: " "))" }
    }

    @Test("lists errors, newest first")
    func fixtures() {
        #expect(summary(SessionIssue.issues(in: QueryFixtures.all)) == [
            "503 Service Unavailable · GET other.example.com/health · e6",
            "Timed out · DELETE api.example.com/users/1 · e5",
            "401 Unauthorized · POST api.example.com/login · e2",
        ])
    }

    @Test("folds the same problem on one endpoint, whatever the query or the adapter's verdict")
    func folding() {
        let entries = [
            call("a", "GET", "/items?page=1", second: 0, status: 500),
            call("b", "GET", "/items?page=2", second: 1, status: 500, failure: .badResponse),
            call("c", "POST", "/items", second: 2, status: 500),
        ]
        let issues = SessionIssue.issues(in: entries.reversed())
        #expect(summary(issues) == [
            "500 Internal Server Error · POST api.example.com/items · c",
            "500 Internal Server Error · GET api.example.com/items · a b",
        ])
        #expect(issues.last?.latestEntryID == PeekId("b"))
        #expect(issues.last?.count == 2)
        #expect(issues.last?.lastSeen == QueryFixtures.start.addingTimeInterval(1))
    }

    @Test("names failures without an error code by their kind, and skips cancellations")
    func failures() {
        let entries = [
            call("parse", second: 0, status: 200, failure: .badResponse),
            call("cancel", second: 1, failure: .cancelled),
            call("offline", second: 2, failure: .connection),
        ]
        #expect(summary(SessionIssue.issues(in: entries)) == [
            "Connection failed · GET api.example.com/items · offline",
            "Unexpected response · GET api.example.com/items · parse",
        ])
    }

    @Test("warns about slow responses from three seconds, after the errors")
    func slow() {
        let entries = [
            call("slow", second: 5, status: 200, ms: 3_000),
            call("fast", second: 6, status: 200, ms: 2_999),
            call("pending", second: 7, ms: nil),
            call("error", second: 0, status: 404, ms: 9_000),
        ]
        let issues = SessionIssue.issues(in: entries)
        #expect(summary(issues) == [
            "404 Not Found · GET api.example.com/items · error",
            "Slow response · GET api.example.com/items · slow",
        ])
        #expect(issues.map(\.severity) == [.error, .warning])
        #expect(entries[0].isSlow && !entries[1].isSlow && !entries[2].isSlow)
    }

    @Test("adds dropped entries as a warning about the session")
    func dropped() {
        let issues = SessionIssue.issues(in: [call("slow", status: 200, ms: 4_000)], droppedCount: 37)
        #expect(issues.map(\.title) == ["The device dropped 37 entries", "Slow response"])
        #expect(issues.first?.entryIDs.isEmpty == true)
        #expect(SessionIssue.issues(in: [], droppedCount: 1).map(\.title) == ["The device dropped 1 entry"])
        #expect(SessionIssue.issues(in: []).isEmpty)
    }
}

@Suite("Insights")
struct SessionInsightsTests {
    @Test("counts, rates and percentiles")
    func numbers() {
        let insights = SessionInsights(QueryFixtures.all)
        #expect(insights.total == 6)
        #expect(insights.finished == 5)
        #expect(insights.errors == 3)
        #expect(insights.errorRate == 0.6)
        #expect(insights.median == .milliseconds(300))
        #expect(insights.p95 == .milliseconds(5_000))
        #expect(insights.sentBytes == 0)
        #expect(insights.receivedBytes > 0)
    }

    @Test("splits statuses, counting an adapter's 4xx failure as 4xx")
    func statuses() {
        let fixtures = SessionInsights(QueryFixtures.all).statuses.map { "\($0.slice.title) \($0.count)" }
        #expect(fixtures == ["2xx 2", "4xx 1", "5xx 1", "Failed 1", "Pending 1"])
        let dio = SessionInsights([
            call("a", status: 404, failure: .badResponse),
            call("b", status: 200, failure: .badResponse),
            call("c", status: 301),
        ])
        #expect(dio.statuses.map { "\($0.slice.title) \($0.count)" } == ["3xx 1", "4xx 1", "Failed 1"])
    }

    @Test("buckets durations with the upper bound excluded")
    func buckets() {
        let insights = SessionInsights(QueryFixtures.all)
        #expect(insights.buckets.map(\.count) == [1, 1, 2, 0, 1, 0])
        let edges = SessionInsights([call("a", status: 200, ms: 100), call("b", status: 200, ms: 10_000), call("c", status: 200, ms: 99)])
        #expect(edges.buckets.map(\.count) == [1, 1, 0, 0, 0, 1])
    }

    @Test("ranks the slowest calls and the busiest hosts")
    func rankings() {
        let insights = SessionInsights(QueryFixtures.all)
        #expect(insights.slowest.map(\.id.value) == ["e5", "e6", "e2", "e1", "e3"])
        #expect(insights.hosts.map { "\($0.name) \($0.count)/\($0.errors)" } == [
            "api.example.com 4/2", "cdn.example.com 1/0", "other.example.com 1/1",
        ])
        #expect(insights.redirected.isEmpty)
    }

    @Test("is empty for no entries")
    func empty() {
        let insights = SessionInsights([])
        #expect(insights.total == 0)
        #expect(insights.errorRate == 0)
        #expect(insights.median == nil)
        #expect(insights.statuses.isEmpty)
        #expect(insights.buckets.allSatisfy { $0.count == 0 })
    }
}
