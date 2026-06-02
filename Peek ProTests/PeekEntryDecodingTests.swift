import Foundation
import Testing
@testable import Peek_Pro

@Suite("Decoding Peek JSON")
struct PeekEntryDecodingTests {
    private func decode(_ line: String) throws -> PeekEntry {
        try PeekEntry(json: Data(line.utf8))
    }

    private func entries(_ name: String) throws -> [PeekEntry] {
        try Spec.entryLines(name).map(decode)
    }

    private func basic() throws -> [String: PeekEntry] {
        Dictionary(uniqueKeysWithValues: try entries("basic.peek").map { ($0.id.value, $0) })
    }

    private func date(_ secondsAfterFixtureStart: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_789_041_600 + secondsAfterFixtureStart)
    }

    @Test("reads every entry of basic.peek in order")
    func basicInOrder() throws {
        let ids = try entries("basic.peek").map(\.id.value)
        let expected = try Spec.manifest()["basic.peek"]?.entries
        #expect(ids == expected)
    }

    @Test("reads unknown-keys.peek exactly like basic.peek")
    func unknownKeys() throws {
        let grown = try entries("unknown-keys.peek")
        let plain = try entries("basic.peek")
        #expect(grown == plain)
    }

    @Test("derives the state and keeps pins")
    func states() throws {
        let all = try basic()
        #expect(all["e1"]?.state == .completed)
        #expect(all["e4"]?.state == .pending)
        #expect(all["e4"]?.completedAt == nil)
        #expect(all["e5"]?.state == .failed)
        #expect(all["e5"]?.isPinned == true)
        #expect(all["e1"]?.isPinned == false)
        #expect(all["e5"]?.failure == PeekFailure(kind: .timeout, message: "slow"))
    }

    @Test("reads times in UTC, microseconds included")
    func times() throws {
        let all = try basic()
        let e1 = try #require(all["e1"])
        #expect(e1.startedAt == date(0))
        let completedAt = try #require(e1.completedAt)
        #expect(abs(completedAt.timeIntervalSince(date(0.12))) < 1e-6)
        let timed = try #require(all["spec-timed"])
        let elapsed = try #require(timed.completedAt).timeIntervalSince(timed.startedAt)
        #expect(abs(elapsed - 0.1875) < 1e-6)
    }

    @Test("reads text, cut-off, byte, form and unavailable bodies")
    func bodies() throws {
        let all = try basic()
        #expect(all["e1"]?.response?.body == .text("body of e1", contentType: PeekMediaType(parsing: "application/json; charset=utf-8")))

        let truncated = try #require(all["spec-truncated"]?.response?.body)
        #expect(truncated.isTruncated)
        #expect(truncated.size == 3_276_800)
        #expect(truncated.capturedSize == "id,name\n1,Ada\n2,Grace\n".utf8.count)

        let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="))
        #expect(all["image"]?.response?.body == .bytes(png, contentType: PeekMediaType("image", "png")))

        #expect(all["upload"]?.request.body == .form(
            fields: [PeekFormField("album", "Holiday")],
            files: [PeekFormFile("photo", filename: "beach.jpg", contentType: PeekMediaType("image", "jpeg"), size: 2_097_152)],
            contentType: .multipartFormData
        ))
        #expect(all["streamed"]?.response?.body == .unavailable(.streamed, size: 73_400_320))
        #expect(all["long-url"]?.response?.body == .empty)
    }

    @Test("keeps repeated headers, cookies and non-ASCII text")
    func headers() throws {
        let timed = try #require(try basic()["spec-timed"])
        #expect(timed.request.headers.values(of: "cookie") == ["session=abc", "theme=dark"])
        #expect(timed.request.headers.names == ["Accept", "Cookie"])
        #expect(timed.response?.headers.setCookies.count == 2)
        #expect(timed.response?.statusMessage == "OK")
        guard case .text(let text, _, _) = timed.response?.body else {
            Issue.record("expected a text body")
            return
        }
        #expect(text.contains("Zürich 🏔"))
    }

    @Test("reads timing phases in milliseconds, fractions included")
    func timings() throws {
        let timings = try #require(try basic()["spec-timed"]?.timings)
        #expect(timings.ssl == .milliseconds(48))
        #expect(timings.send == .microseconds(1500))
        #expect(timings.known.count == 7)
        let e1 = try basic()["e1"]
        #expect(e1?.timings == nil)
    }

    @Test("reads redirects, failures and extra data")
    func details() throws {
        let all = try basic()
        let redirects = try #require(all["redirect"]?.response?.redirects)
        #expect(redirects.map(\.statusCode) == [301, 302])
        #expect(redirects.first?.location == URL(string: "https://example.com/docs"))
        #expect(all["upload"]?.response?.statusMessage == "Created")

        let crashed = try #require(all["spec-crashed"])
        #expect(crashed.source == "talker/dio")
        #expect(crashed.failure?.kind == .connection)
        #expect(crashed.failure?.details == "SocketException: Connection reset by peer (OS Error: 54)")
        #expect(crashed.failure?.stackTrace?.hasPrefix("#0      PaymentApi.charge") == true)
        #expect(crashed.request.extra == ["retry": "2", "traceId": "a1b2c3"])
        #expect(all["cancelled"]?.failure?.kind == .cancelled)
    }

    @Test("falls back on kinds a newer Peek writes")
    func newerKinds() throws {
        let lines = try Spec.entryLines("future-version.peek")
        let entries = lines.compactMap { try? decode($0) }
        let expected = try Spec.manifest()["future-version.peek"]?.entries
        #expect(entries.map(\.id.value) == expected)
        #expect(entries[1].response?.body == .unavailable(.notCaptured, contentType: PeekMediaType("image", "png"), size: 48_213))
        #expect(entries[2].failure?.kind == .unknown)
        #expect(throws: (any Error).self) { try decode(lines[3]) }
    }

    @Test("reads extra values that are not strings as JSON")
    func extraValues() throws {
        let entry = try decode(#"""
        {"id":"x","source":"dio","startedAt":"2026-09-10T12:00:00Z","request":{"method":"get","url":"https://a.example/","extra":{"n":1.5,"ok":true,"none":null,"list":[1,"a/b"],"map":{"b":2,"a":1}}}}
        """#)
        #expect(entry.request.method == "GET")
        #expect(entry.request.extra == ["n": "1.5", "ok": "true", "none": "null", "list": #"[1,"a/b"]"#, "map": #"{"a":1,"b":2}"#])
    }

    @Test("refuses an entry that breaks the format", arguments: [
        #"{"source":"dio","startedAt":"2026-09-10T12:00:00Z","request":{"method":"GET","url":"https://a.example/"}}"#,
        #"{"id":"","source":"dio","startedAt":"2026-09-10T12:00:00Z","request":{"method":"GET","url":"https://a.example/"}}"#,
        #"{"id":"x","source":"dio","startedAt":"2026-09-10T12:00:00Z"}"#,
        #"{"id":"x","source":"dio","startedAt":"yesterday","request":{"method":"GET","url":"https://a.example/"}}"#,
        #"{"id":"x","source":"dio","startedAt":"2026-09-10T12:00:00Z","completedAt":"2026-09-10T12:00:01Z","request":{"method":"GET","url":"https://a.example/"}}"#,
        #"{"id":"x","source":"dio","startedAt":"2026-09-10T12:00:00Z","request":{"method":"GET","url":"https://a.example/"},"response":{"status":200}}"#,
        #"{"id":"x","source":"dio","startedAt":"2026-09-10T12:00:00Z","completedAt":"2026-09-10T12:00:01Z","request":{"method":"GET","url":"https://a.example/"},"response":{"status":"200"}}"#,
        #"{"id":"x","source":"dio","startedAt":"2026-09-10T12:00:00Z","request":{"method":"GET","url":"https://a.example/","headers":[["a","b","c"]]}}"#,
        #"{"id":"x","source":"dio","startedAt":"2026-09-10T12:00:00Z","request":{"method":"GET","url":"https://a.example/","body":{"kind":"bytes","bytes":"***"}}}"#,
        #"{"id":"x","source":"dio","startedAt":"2026-09-10T12:00:00Z","pinned":"yes","request":{"method":"GET","url":"https://a.example/"}}"#,
        #"42"#,
    ])
    func refuses(_ line: String) {
        #expect(throws: (any Error).self) { try decode(line) }
    }

    @Test("treats null like an absent key")
    func nulls() throws {
        let entry = try decode(#"""
        {"id":"x","source":"dio","startedAt":"2026-09-10T12:00:00Z","completedAt":null,"pinned":null,"timings":null,"request":{"method":"GET","url":"https://a.example/","headers":null,"body":null}}
        """#)
        #expect(entry.state == .pending)
        #expect(entry.request.body == .empty)
    }
}

@Suite("Peek timestamps")
struct PeekTimestampTests {
    @Test("reads any fraction and any offset", arguments: [
        ("2026-09-10T12:00:00Z", 0.0),
        ("2026-09-10T12:00:00.120Z", 0.12),
        ("2026-09-10T12:00:00.187500Z", 0.1875),
        ("2026-09-10T12:00:00.187500000z", 0.1875),
        ("2026-09-10T19:00:00+07:00", 0.0),
        ("2026-09-10T11:30:00.5-0030", 0.5),
    ])
    func reads(_ text: String, _ seconds: Double) throws {
        let date = try #require(PeekTimestamp.parse(text))
        #expect(abs(date.timeIntervalSince1970 - (1_789_041_600 + seconds)) < 1e-6)
    }

    @Test("reads a leap-year day and the epoch")
    func calendar() {
        #expect(PeekTimestamp.parse("1970-01-01T00:00:00Z") == Date(timeIntervalSince1970: 0))
        #expect(PeekTimestamp.parse("2024-02-29T00:00:00Z") == Date(timeIntervalSince1970: 1_709_164_800))
    }

    @Test("refuses what is not a time", arguments: [
        "", "2026-09-10", "2026-09-10T12:00:00", "2026-13-01T00:00:00Z", "2026-09-10T12:00:00.Z",
        "2026-09-10T12:00:00Z ", "2026-09-10 12:00:00Z", "yesterday",
    ])
    func refuses(_ text: String) {
        #expect(PeekTimestamp.parse(text) == nil)
    }
}

@Suite("Peek platforms")
struct PeekPlatformTests {
    @Test("keeps a platform it does not know as it came")
    func platforms() {
        #expect(PeekPlatform(rawValue: "ios") == .iOS)
        #expect(PeekPlatform(rawValue: "fuchsia") == .fuchsia)
        #expect(PeekPlatform(rawValue: "unknown") == .unknown)
        #expect(PeekPlatform(rawValue: "visionos") == .other("visionos"))
        #expect(PeekPlatform(rawValue: "visionos").title == "visionos")
        for raw in ["ios", "android", "macos", "windows", "linux", "fuchsia", "web", "unknown", "tvos"] {
            #expect(PeekPlatform(rawValue: raw).rawValue == raw)
        }
    }
}
