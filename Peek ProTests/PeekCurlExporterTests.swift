import Foundation
import Testing
@testable import Peek_Pro

/// The cases of Peek's `peek_curl_exporter_test.dart`, so both exporters give the same commands.
@Suite("cURL exporter")
struct PeekCurlExporterTests {
    private let exporter = PeekCurlExporter()
    private let url = "https://api.example.com/users?page=1&q=a%20b"

    private func request(method: String = "GET", headers: [(String, String)] = [], body: PeekBody = .empty) -> PeekRequest {
        PeekRequest(method: method, uri: URL(string: url)!, headers: PeekHeaders(headers), body: body)
    }

    @Test("keeps a plain GET minimal")
    func plainGet() {
        #expect(exporter.exportRequest(request()) == "curl '\(url)'")
    }

    @Test("spells out method, headers and a text body over lines")
    func post() {
        let command = exporter.exportRequest(request(
            method: "POST",
            headers: [("Content-Type", "application/json"), ("Authorization", "*****")],
            body: .text(#"{"name":"Ann"}"#, contentType: .json)
        ))
        #expect(command == """
            curl -X POST '\(url)' \\
              -H 'Content-Type: application/json' \\
              -H 'Authorization: *****' \\
              --data-raw '{"name":"Ann"}'
            """)
    }

    @Test("fits on one line when asked")
    func singleLine() {
        let single = PeekCurlExporter(multiline: false)
        #expect(single.exportRequest(request(method: "DELETE", headers: [("Accept", "*/*")]))
            == "curl -X DELETE '\(url)' -H 'Accept: */*'")
    }

    @Test("quotes single quotes the POSIX way")
    func quoting() {
        let command = exporter.exportRequest(request(
            method: "POST",
            headers: [("X-Note", #"it's "quoted""#)],
            body: .text("{'a':'b'}")
        ))
        #expect(command.contains(#"-H 'X-Note: it'\''s "quoted"'"#))
        #expect(command.contains(#"--data-raw '{'\''a'\'':'\''b'\''}'"#))
    }

    @Test("drops Content-Length and repeats multi-valued headers")
    func headers() {
        let command = exporter.exportRequest(request(headers: [
            ("Content-Length", "12"), ("Accept", "text/html"), ("Accept", "application/json"),
        ]))
        #expect(!command.contains("Content-Length"))
        #expect(command.contains("-H 'Accept: text/html'"))
        #expect(command.contains("-H 'Accept: application/json'"))
    }

    @Test("adds -X GET only when a GET carries data")
    func getWithData() {
        #expect(exporter.exportRequest(request(body: .text("x"))).hasPrefix("curl -X GET 'https://"))
        #expect(exporter.exportRequest(request(body: .unavailable(.streamed)))
            == "curl '\(url)'\n# body not captured (streamed)")
    }

    @Test("asks for headers only on HEAD")
    func head() {
        #expect(exporter.exportRequest(request(method: "HEAD")) == "curl -I '\(url)'")
    }

    @Test("URL-encodes plain form fields")
    func urlEncodedForm() {
        let command = exporter.exportRequest(request(
            method: "POST",
            headers: [("Content-Type", "application/x-www-form-urlencoded")],
            body: .form(fields: [PeekFormField("user", "ann smith"), PeekFormField("note", "a&b=c")], contentType: .formUrlEncoded)
        ))
        #expect(command == """
            curl -X POST '\(url)' \\
              -H 'Content-Type: application/x-www-form-urlencoded' \\
              --data-urlencode 'user=ann smith' \\
              --data-urlencode 'note=a&b=c'
            """)
    }

    @Test("sends multipart forms with -F and lets curl set the boundary")
    func multipart() {
        let command = exporter.exportRequest(request(
            method: "POST",
            headers: [("Content-Type", "multipart/form-data; boundary=xyz")],
            body: .form(
                fields: [PeekFormField("album", "Holiday; 2026")],
                files: [
                    PeekFormFile("photo", filename: "beach.jpg", contentType: PeekMediaType(parsing: "image/jpeg")),
                    PeekFormFile("raw"),
                ],
                contentType: .multipartFormData
            )
        ))
        #expect(command == """
            curl -X POST '\(url)' \\
              --form-string 'album=Holiday; 2026' \\
              -F 'photo=@beach.jpg;type=image/jpeg' \\
              -F 'raw=@raw'
            # file contents are not captured; point @ at real files
            """)
    }

    @Test("treats a form with files as multipart even without a type")
    func filesMeanMultipart() {
        let command = exporter.exportRequest(request(method: "POST", body: .form(files: [PeekFormFile("f", filename: "x")])))
        #expect(command.contains("-F 'f=@x'"))
        #expect(!command.contains("--data-urlencode"))
    }

    @Test("points binary bodies at a file and says so")
    func binary() {
        let command = exporter.exportRequest(request(method: "PUT", body: .bytes(Data([1, 2, 3]), contentType: .octetStream)))
        #expect(command == """
            curl -X PUT '\(url)' \\
              --data-binary '@body.bin'
            # body.bin: 3 bytes of application/octet-stream, not exported
            """)
    }

    @Test("notes a truncated body after the command")
    func truncated() {
        let truncated = request(method: "POST", body: .text("abc", size: 1_000))
        #expect(exporter.exportRequest(truncated).hasSuffix("--data-raw 'abc'\n# body truncated: 3 of 1000 bytes"))
        #expect(PeekCurlExporter(multiline: false).exportRequest(truncated)
            .hasSuffix("--data-raw 'abc' # body truncated: 3 of 1000 bytes"))
    }

    @Test("says when the body is still on the device")
    func remote() {
        #expect(exporter.exportRequest(request(method: "POST", body: .remote(size: 10)))
            == "curl -X POST '\(url)'\n# body still on the device; load it to include it")
    }

    @Test("exports an entry through its request")
    func entry() {
        let entry = PeekEntry(id: PeekId("e"), request: request(method: "DELETE"), startedAt: QueryFixtures.start, source: "test")
        #expect(exporter.export(entry) == exporter.exportRequest(entry.request))
        #expect(exporter.export(entry).hasPrefix("curl -X DELETE 'https://"))
        #expect(PeekExporters.url(entry) == url)
    }

    @Test("highlights the notes as comments")
    func highlighting() {
        let command = "curl -X PUT 'x' --data-binary '@body.bin'\n# body.bin: 3 bytes"
        let comment = CurlHighlighter.tokens(in: command).last
        #expect(comment?.range == NSRange(location: 42, length: 19))
    }
}
