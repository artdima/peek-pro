import Foundation
import Testing
@testable import Peek_Pro

@Suite("Search query")
struct PeekSearchQueryTests {
    private typealias F = QueryFixtures

    private static let login = PeekEntry(
        id: PeekId("login"),
        request: PeekRequest(
            method: "POST",
            uri: URL(string: "https://api.example.com/login")!,
            headers: ["X-Client": "MobileApp/2.1"],
            body: .text(#"{"user":"Ann","remember":true}"#)
        ),
        startedAt: F.start,
        source: "dio",
        response: PeekResponse(statusCode: 200, headers: ["X-Trace": "abc-123"], body: .text(#"{"greeting":"Welcome back"}"#)),
        completedAt: F.start
    )

    private static let upload = PeekEntry(
        id: PeekId("upload"),
        request: PeekRequest(
            method: "POST",
            uri: URL(string: "https://api.example.com/upload")!,
            body: .form(fields: [PeekFormField("album", "Holiday")], files: [PeekFormFile("photo", filename: "beach.jpg")])
        ),
        startedAt: F.start,
        source: "dio",
        failure: PeekFailure(kind: .connection, message: "Connection reset by peer", details: "errno 54"),
        completedAt: F.start
    )

    private let all = F.all + [Self.login, Self.upload]

    private func found(_ query: PeekSearchQuery) -> [String] {
        F.ids(query.apply(all))
    }

    private func found(in scope: PeekSearchScope, _ text: String) -> [String] {
        found(PeekSearchQuery(text, scopes: [scope]))
    }

    @Test("matches everything when empty")
    func empty() {
        #expect(PeekSearchQuery.none.isEmpty)
        #expect(PeekSearchQuery("   ").isEmpty)
        #expect(PeekSearchQuery("x", scopes: []).isEmpty)
        #expect(found(PeekSearchQuery.none) == F.ids(all))
        #expect(PeekSearchQuery.none.matches(Self.login))
    }

    @Test("searches URLs, ignoring case")
    func url() {
        #expect(found(PeekSearchQuery("USERS", scopes: [.url])) == ["e1", "e5"])
        #expect(found(PeekSearchQuery("cdn.EXAMPLE")) == ["e3"])
    }

    @Test("searches header names and values on both sides")
    func headers() {
        #expect(found(in: .headers, "x-client") == ["login"])
        #expect(found(in: .headers, "mobileapp") == ["login"])
        #expect(found(in: .headers, "abc-123") == ["login"])
        #expect(found(in: .headers, "image/png") == ["e3"])
        #expect(found(in: .url, "abc-123").isEmpty)
    }

    @Test("searches text and form request bodies")
    func requestBody() {
        #expect(found(in: .requestBody, "ann") == ["login"])
        #expect(found(in: .requestBody, "holiday") == ["upload"])
        #expect(found(in: .requestBody, "beach.jpg") == ["upload"])
        #expect(found(in: .requestBody, "photo") == ["upload"])
        #expect(found(in: .requestBody, "welcome").isEmpty)
    }

    @Test("searches response bodies")
    func responseBody() {
        #expect(found(in: .responseBody, "welcome") == ["login"])
        #expect(found(in: .responseBody, "body of e2") == ["e2"])
        #expect(found(in: .responseBody, "ann").isEmpty)
    }

    @Test("searches failure kind, message and details")
    func error() {
        #expect(found(in: .error, "timeout") == ["e5"])
        #expect(found(in: .error, "reset by peer") == ["upload"])
        #expect(found(in: .error, "errno") == ["upload"])
        #expect(found(in: .error, "login").isEmpty)
    }

    @Test("looks everywhere by default and trims the text")
    func defaults() {
        #expect(found(PeekSearchQuery("  errno ")) == ["upload"])
        #expect(found(PeekSearchQuery("example.com")) == F.ids(all))
    }

    @Test("treats the text literally, not as a pattern")
    func literal() {
        #expect(found(PeekSearchQuery(".*")).isEmpty)
        #expect(found(PeekSearchQuery("users/1")) == ["e5"])
    }

    @Test("searches bodies only up to the cap")
    func cap() {
        let long = PeekEntry(
            id: PeekId("long"),
            request: PeekRequest(method: "GET", uri: URL(string: "https://example.com/")!,
                                 body: .text(String(repeating: "a", count: 100) + "needle")),
            startedAt: F.start,
            source: "dio"
        )
        var capped = PeekSearchQuery("needle", maxBodyLength: 50)
        #expect(!capped.matches(long))
        capped.maxBodyLength = 200
        #expect(capped.matches(long))
        #expect(PeekSearchQuery("needle").matches(long))
    }

    @Test("compares by value")
    func equality() {
        let query = PeekSearchQuery("a", scopes: [.url])
        #expect(query == PeekSearchQuery("a", scopes: [.url]))
        #expect(query.hashValue == PeekSearchQuery("a", scopes: [.url]).hashValue)
        #expect(query != PeekSearchQuery("a"))
        var shorter = query
        shorter.maxBodyLength = 1
        #expect(query != shorter)
    }

    @Test("console scopes map onto query scopes")
    func consoleScopes() {
        #expect(ConsoleSearchScope.all.scopes == Set(PeekSearchScope.allCases))
        #expect(ConsoleSearchScope.body.scopes == [.requestBody, .responseBody])
        #expect(ConsoleSearchScope.errors.scopes == [.error])
    }
}
