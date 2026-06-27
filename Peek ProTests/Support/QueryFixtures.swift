import Foundation
@testable import Peek_Pro

/// The entries Peek's query tests share (`test/support/entries.dart`), so both sides check the same cases.
///
/// | id | call                           | outcome          | src    | ms   |
/// |----|--------------------------------|------------------|--------|------|
/// | e1 | GET api.example.com/users      | 200 json         | dio    | 120  |
/// | e2 | POST api.example.com/login     | 401 json         | dio    | 300  |
/// | e3 | GET cdn.example.com/logo.png   | 200 image/png    | dio    | 40   |
/// | e4 | GET api.example.com/slow       | pending          | talker | —    |
/// | e5 | DELETE api.example.com/users/1 | timeout, pinned  | talker | 5000 |
/// | e6 | GET other.example.com/health   | 503 text/plain   | dio    | 800  |
enum QueryFixtures {
    static let start = Date(timeIntervalSince1970: 1_789_041_600)

    static let e1 = entry("e1", "GET", "https://api.example.com/users", second: 0, source: "dio",
                          status: 200, type: "application/json; charset=utf-8", ms: 120)
    static let e2 = entry("e2", "POST", "https://api.example.com/login", second: 1, source: "dio",
                          status: 401, type: "application/json", ms: 300)
    static let e3 = entry("e3", "GET", "https://cdn.example.com/logo.png", second: 2, source: "dio",
                          status: 200, type: "image/png", ms: 40)
    static let e4 = entry("e4", "GET", "https://api.example.com/slow", second: 3, source: "talker")
    static let e5 = entry("e5", "DELETE", "https://api.example.com/users/1", second: 4, source: "talker",
                          ms: 5_000, failure: PeekFailure(kind: .timeout, message: "slow"), pinned: true)
    static let e6 = entry("e6", "GET", "https://Other.Example.com/health", second: 5, source: "dio",
                          status: 503, type: "text/plain", ms: 800)

    static let all = [e1, e2, e3, e4, e5, e6]

    static func ids(_ entries: [PeekEntry]) -> [String] {
        entries.map(\.id.value)
    }

    private static func entry(
        _ id: String,
        _ method: String,
        _ url: String,
        second: Int,
        source: String,
        status: Int? = nil,
        type: String? = nil,
        ms: Int? = nil,
        failure: PeekFailure? = nil,
        pinned: Bool = false
    ) -> PeekEntry {
        let startedAt = start.addingTimeInterval(TimeInterval(second))
        let response = status.map { status in
            PeekResponse(
                statusCode: status,
                headers: type.map { PeekHeaders([("Content-Type", $0)]) } ?? .empty,
                body: .text("body of \(id)", contentType: PeekMediaType(parsing: type))
            )
        }
        return PeekEntry(
            id: PeekId(id),
            request: PeekRequest(method: method, uri: URL(string: url)!),
            startedAt: startedAt,
            source: source,
            response: response,
            failure: failure,
            completedAt: ms.map { startedAt.addingTimeInterval(TimeInterval($0) / 1_000) },
            isPinned: pinned
        )
    }
}
