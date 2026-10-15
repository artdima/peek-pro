import Foundation
import Testing
@testable import Peek_Pro

@Suite("Sizes")
struct PeekSizeTests {
    private func entry(sent: String, received: String) -> PeekEntry {
        let start = Date(timeIntervalSince1970: 1_789_041_600)
        return PeekEntry(
            id: PeekId("x"),
            request: PeekRequest(method: "POST", uri: URL(string: "https://a.example/")!, headers: ["Content-Length": sent]),
            startedAt: start,
            source: "dio",
            response: PeekResponse(statusCode: 200, headers: ["Content-Length": received]),
            completedAt: start.addingTimeInterval(1)
        )
    }

    @Test("reads Content-Length only when it is a plain number that fits", arguments: [
        ("42", 42),
        ("0", 0),
        ("-5", nil),
        ("+5", nil),
        ("12 bytes", nil),
        ("", nil),
        ("9223372036854775808", nil),
    ] as [(String, Int?)])
    func contentLength(_ header: String, _ expected: Int?) {
        let headers: PeekHeaders = ["Content-Length": header]
        #expect(headers.contentLength == expected)
    }

    @Test("adds sizes up to the largest Int instead of overflowing")
    func totals() {
        let huge = entry(sent: "9223372036854775807", received: "10")
        #expect(huge.totalSize == .max)
        #expect([huge, huge].compactMap(\.totalSize).saturatingSum() == .max)

        let insights = SessionInsights([huge, huge])
        #expect(insights.sentBytes == .max)
        #expect(insights.receivedBytes > 0)

        #expect(entry(sent: "3", received: "4").totalSize == 7)
        #expect([Int.min, -1].saturatingSum() == .min)
        #expect([1, 2, 3].saturatingSum() == 6)
    }
}
