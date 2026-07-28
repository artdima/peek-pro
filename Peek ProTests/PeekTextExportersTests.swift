import Foundation
import Testing
@testable import Peek_Pro

/// The cases of Peek's `peek_text_exporter_test.dart` and `peek_markdown_exporter_test.dart`.
private let started = QueryFixtures.start

private func entry(
    requestBody: PeekBody = .empty,
    requestHeaders: [(String, String)] = [],
    response: PeekResponse? = nil,
    failure: PeekFailure? = nil,
    took: Duration = .milliseconds(250)
) -> PeekEntry {
    PeekEntry(
        id: PeekId("e"),
        request: PeekRequest(
            method: "POST",
            uri: URL(string: "https://api.example.com/login")!,
            headers: PeekHeaders(requestHeaders),
            body: requestBody
        ),
        startedAt: started,
        source: "dio",
        response: response,
        failure: failure,
        completedAt: response == nil && failure == nil ? nil : started.addingTimeInterval(took.timeInterval)
    )
}

@Suite("Text exporter")
struct PeekTextExporterTests {
    private let exporter = PeekTextExporter()

    @Test("writes a completed call in full")
    func completed() {
        let text = exporter.export(entry(
            requestBody: .text(#"{"user":"ann"}"#),
            requestHeaders: [("Content-Type", "application/json")],
            response: PeekResponse(statusCode: 200, statusMessage: "OK", headers: ["Content-Length": "9"], body: .text(#"{"ok":1}"#))
        ))
        #expect(text == """
            POST https://api.example.com/login
            200 OK · 250 ms · ↑ 14 B · ↓ 9 B · 2026-09-10T12:00:00.000Z · dio

            --- Request ---
            Content-Type: application/json

            {"user":"ann"}

            --- Response ---
            Content-Length: 9

            {"ok":1}
            """)
    }

    @Test("leaves out sizes nothing was sent or received in")
    func noSizes() {
        let text = exporter.export(entry(response: PeekResponse(statusCode: 204)))
        #expect(!text.contains("↑"))
        #expect(!text.contains("↓"))
        #expect(text.contains("204 · 250 ms · 2026-09-10"))
    }

    @Test("says when a call is still pending")
    func pending() {
        let text = exporter.export(entry())
        #expect(text == """
            POST https://api.example.com/login
            Pending · 2026-09-10T12:00:00.000Z · dio

            --- Request ---
            (no headers)
            """)
    }

    @Test("writes failures with details and a trace")
    func failure() {
        let text = exporter.export(entry(
            failure: PeekFailure(kind: .connection, message: "Connection reset", details: "errno 54", stackTrace: "#0 main\n#1 run\n"),
            took: .seconds(2)
        ))
        #expect(text.contains("Failed: connection · 2 s ·"))
        #expect(text.hasSuffix("""
            --- Error ---
            connection: Connection reset
            Details: errno 54

            #0 main
            #1 run
            """))
    }

    @Test("describes bodies it cannot print")
    func unprintable() {
        #expect(exporter.export(entry(requestBody: .bytes(Data(count: 2_048), contentType: .octetStream)))
            .contains("<2 KB of application/octet-stream>"))
        #expect(exporter.export(entry(requestBody: .unavailable(.streamed))).contains("<body not captured: streamed>"))
        let form = exporter.export(entry(requestBody: .form(
            fields: [PeekFormField("album", "Holiday")],
            files: [PeekFormFile("photo", filename: "beach.jpg", size: 4_096), PeekFormFile("raw")]
        )))
        #expect(form.contains("album: Holiday\nphoto: <file beach.jpg, 4 KB>\nraw: <file >"))
        #expect(exporter.export(entry(requestBody: .remote(size: 3_072))).contains("<body still on the device: 3 KB>"))
    }

    @Test("skips empty bodies and cuts long ones")
    func bodies() {
        #expect(!exporter.export(entry()).contains("\n\n\n"))
        #expect(!exporter.export(entry(requestBody: .text(""))).contains("---\n\n"))
        let cut = PeekTextExporter(maxBodyChars: 10).export(entry(requestBody: .text("0123456789abcdef")))
        #expect(cut.contains("0123456789\n… 6 more characters"))
        #expect(!cut.contains("abcdef"))
    }

    @Test("formats sizes and durations by magnitude")
    func magnitudes() {
        func outcome(after took: Duration) -> String {
            exporter.export(entry(response: PeekResponse(statusCode: 204), took: took)).components(separatedBy: "\n")[1]
        }
        #expect(outcome(after: .microseconds(900)).contains("900 µs"))
        #expect(outcome(after: .milliseconds(1_500)).contains("1.5 s"))
        #expect(outcome(after: .seconds(90)).contains("1m 30s"))
        #expect(exporter.export(entry(requestBody: .bytes(Data(count: 1_536)))).contains("↑ 1.5 KB"))
        #expect(exporter.export(entry(requestBody: .bytes(Data(count: 3 * 1_024 * 1_024)))).contains("↑ 3 MB"))
    }

    @Test("writes timestamps like Dart's toIso8601String")
    func timestamps() {
        #expect(PeekExportFormat.timestamp(started) == "2026-09-10T12:00:00.000Z")
        #expect(PeekExportFormat.timestamp(started.addingTimeInterval(0.123)) == "2026-09-10T12:00:00.123Z")
        #expect(PeekExportFormat.timestamp(started.addingTimeInterval(0.000_123)) == "2026-09-10T12:00:00.000123Z")
    }

    @Test("handles every fixture")
    func fixtures() {
        for fixture in QueryFixtures.all {
            #expect(exporter.export(fixture).hasPrefix(fixture.request.method))
        }
    }
}

@Suite("Markdown exporter")
struct PeekMarkdownExporterTests {
    private let exporter = PeekMarkdownExporter()

    @Test("writes a heading, a summary table and both halves")
    func full() {
        let markdown = exporter.export(entry(
            requestBody: .text(#"{"user":"ann"}"#, contentType: .json),
            requestHeaders: [("Content-Type", "application/json")],
            response: PeekResponse(statusCode: 200, statusMessage: "OK", headers: ["Content-Type": "text/html"], body: .text("<b>hi</b>", contentType: .html))
        ))
        #expect(markdown == """
            ### POST https://api.example.com/login

            | Field | Value |
            | --- | --- |
            | Outcome | `200` OK |
            | Duration | 250 ms |
            | Request | 14 B |
            | Response | 9 B |
            | Started | 2026-09-10T12:00:00.000Z |
            | Source | `dio` |

            #### Request

            | Header | Value |
            | --- | --- |
            | `Content-Type` | application/json |

            ```json
            {"user":"ann"}
            ```

            #### Response

            | Header | Value |
            | --- | --- |
            | `Content-Type` | text/html |

            ```html
            <b>hi</b>
            ```
            """)
    }

    @Test("tags fences by media type and leaves unknown ones bare")
    func fences() {
        func fence(_ type: PeekMediaType?) -> String? {
            exporter.export(entry(requestBody: .text("x", contentType: type)))
                .components(separatedBy: "\n").first { $0.hasPrefix("```") }
        }
        #expect(fence(.json) == "```json")
        #expect(fence(PeekMediaType(parsing: "application/xml")) == "```xml")
        #expect(fence(.html) == "```html")
        #expect(fence(.plainText) == "```")
        #expect(fence(nil) == "```")
    }

    @Test("escapes pipes so the header table survives")
    func pipes() {
        #expect(exporter.export(entry(requestHeaders: [("Accept", "a|b")])).contains(#"| `Accept` | a\|b |"#))
    }

    @Test("says when there are no headers")
    func noHeaders() {
        #expect(exporter.export(entry()).contains("#### Request\n\n_No headers._"))
    }

    @Test("writes pending and failed outcomes")
    func outcomes() {
        #expect(exporter.export(entry()).contains("| Outcome | Pending |"))
        let failed = exporter.export(entry(failure: PeekFailure(kind: .timeout, message: "too slow", details: "after 30s")))
        #expect(failed.contains("#### Error\n\n**timeout** — too slow\n\n```\nafter 30s\n```"))
    }

    @Test("handles every fixture")
    func fixtures() {
        for fixture in QueryFixtures.all {
            #expect(exporter.export(fixture).hasPrefix("### "))
        }
    }

    @Test("offers every format from one place")
    func exporters() {
        let value = entry(response: PeekResponse(statusCode: 200))
        #expect(PeekExporters.url(value) == "https://api.example.com/login")
        #expect(PeekExporters.curl.export(value).hasPrefix("curl -X POST"))
        #expect(PeekExporters.text.export(value).hasPrefix("POST https://"))
        #expect(PeekExporters.markdown.export(value).hasPrefix("### POST"))
    }
}
