import Foundation
import Testing
@testable import Peek_Pro

/// The cases of Peek's `peek_har_exporter_test.dart`; parts of the document are compared as compact JSON.
@Suite("HAR exporter")
struct PeekHarExporterTests {
    private let exporter = PeekHarExporter(creatorVersion: "9.9.9")
    private let started = QueryFixtures.start

    private func entries(_ entries: [PeekEntry]) -> [JSONValue] {
        exporter.toJSON(entries)["log"]?["entries"]?.items ?? []
    }

    private func single(_ entry: PeekEntry) -> JSONValue {
        entries([entry]).first ?? .null
    }

    private var rich: PeekEntry {
        PeekEntry(
            id: PeekId("rich"),
            request: PeekRequest(
                method: "POST",
                uri: URL(string: "https://api.example.com/items?q=a&q=b&page=2")!,
                headers: PeekHeaders([("Content-Type", "application/json"), ("Cookie", "sid=abc; theme=dark")]),
                body: .text(#"{"name":"x"}"#, contentType: .json)
            ),
            startedAt: started,
            source: "dio",
            response: response(),
            completedAt: started.addingTimeInterval(0.25)
        )
    }

    private func response(
        headers: PeekHeaders = PeekHeaders([
            ("Content-Type", "application/json; charset=utf-8"),
            ("Location", "https://api.example.com/items/9"),
            ("Set-Cookie", "sid=def; Path=/; HttpOnly"),
        ]),
        body: PeekBody = .text(#"{"id":9}"#, contentType: .json)
    ) -> PeekResponse {
        PeekResponse(statusCode: 201, statusMessage: "Created", headers: headers, body: body)
    }

    private func with(_ entry: PeekEntry, request body: PeekBody? = nil, response: PeekResponse? = nil, timings: PeekTimings? = nil) -> PeekEntry {
        PeekEntry(
            id: entry.id,
            request: body.map { PeekRequest(method: entry.request.method, uri: entry.request.uri, headers: entry.request.headers, body: $0) } ?? entry.request,
            startedAt: entry.startedAt,
            source: entry.source,
            response: response ?? entry.response,
            completedAt: entry.completedAt,
            timings: timings
        )
    }

    @Test("writes a HAR 1.2 log with Peek Pro as the creator")
    func log() {
        let log = exporter.toJSON(QueryFixtures.all)["log"]
        #expect(log?["version"]?.encoded() == #""1.2""#)
        #expect(log?["creator"]?.encoded() == #"{"name":"Peek Pro","version":"9.9.9"}"#)
    }

    @Test("leaves pending calls out and keeps failed ones")
    func pending() {
        let ids = entries(QueryFixtures.all).compactMap { $0["_peek"]?["id"]?.encoded() }
        #expect(ids == [#""e1""#, #""e2""#, #""e3""#, #""e5""#, #""e6""#])
    }

    @Test("maps the request half")
    func request() {
        let request = single(rich)["request"]
        #expect(request?["method"]?.encoded() == #""POST""#)
        #expect(request?["url"]?.encoded() == #""https://api.example.com/items?q=a&q=b&page=2""#)
        #expect(request?["httpVersion"]?.encoded() == #""HTTP/1.1""#)
        #expect(request?["headers"]?.encoded()
            == #"[{"name":"Content-Type","value":"application/json"},{"name":"Cookie","value":"sid=abc; theme=dark"}]"#)
        #expect(request?["cookies"]?.encoded()
            == #"[{"name":"sid","value":"abc","httpOnly":false,"secure":false},{"name":"theme","value":"dark","httpOnly":false,"secure":false}]"#)
        #expect(request?["queryString"]?.encoded()
            == #"[{"name":"q","value":"a"},{"name":"q","value":"b"},{"name":"page","value":"2"}]"#)
        #expect(request?["postData"]?.encoded() == #"{"mimeType":"application/json","text":"{\"name\":\"x\"}"}"#)
        #expect(request?["headersSize"]?.encoded() == "-1")
        #expect(request?["bodySize"]?.encoded() == "12")
    }

    @Test("maps the response half")
    func responseHalf() {
        let response = single(rich)["response"]
        #expect(response?["status"]?.encoded() == "201")
        #expect(response?["statusText"]?.encoded() == #""Created""#)
        #expect(response?["redirectURL"]?.encoded() == #""https://api.example.com/items/9""#)
        #expect(response?["cookies"]?.encoded() == #"[{"name":"sid","value":"def","path":"/","httpOnly":true,"secure":false}]"#)
        #expect(response?["content"]?.encoded() == #"{"size":8,"mimeType":"application/json","text":"{\"id\":9}"}"#)
        #expect(response?["bodySize"]?.encoded() == "8")
    }

    @Test("records when the call started and how long it took")
    func timing() {
        let entry = single(rich)
        #expect(entry["startedDateTime"]?.encoded() == #""2026-09-10T12:00:00.000Z""#)
        #expect(entry["time"]?.encoded() == "250.0")
        #expect(entry["timings"]?.encoded()
            == #"{"blocked":-1.0,"dns":-1.0,"connect":-1.0,"ssl":-1.0,"send":0.0,"wait":250.0,"receive":0.0}"#)
        #expect(entry["cache"]?.encoded() == "{}")
    }

    @Test("writes known phase timings in milliseconds")
    func phases() {
        let timed = with(rich, timings: PeekTimings(
            dns: .milliseconds(3), connect: .microseconds(1_500), send: .milliseconds(1), wait: .milliseconds(200), receive: .milliseconds(40)
        ))
        #expect(single(timed)["timings"]?.encoded()
            == #"{"blocked":-1.0,"dns":3.0,"connect":1.5,"ssl":-1.0,"send":1.0,"wait":200.0,"receive":40.0}"#)
    }

    @Test("gives the phases it was not told about to wait")
    func leftoverWait() {
        let timed = with(rich, timings: PeekTimings(
            dns: .milliseconds(10), connect: .milliseconds(20), ssl: .milliseconds(15), send: .milliseconds(5), receive: .milliseconds(15)
        ))
        let entry = single(timed)
        #expect(entry["timings"]?["wait"]?.encoded() == "200.0")
        #expect(entry["time"]?.encoded() == "250.0")
    }

    @Test("writes cookie expiry as an ISO 8601 time")
    func cookieExpiry() {
        let entry = single(with(rich, response: response(headers: PeekHeaders([
            ("Set-Cookie", "sid=def; Expires=Wed, 21 Oct 2015 07:28:00 GMT"),
            ("Set-Cookie", "theme=dark; Expires=whenever"),
        ]))))
        let cookies = entry["response"]?["cookies"]?.items ?? []
        #expect(cookies.first?["expires"]?.encoded() == #""2015-10-21T07:28:00.000Z""#)
        #expect(cookies.last?.keys.contains("expires") == false)
    }

    @Test("base64-encodes binary bodies on both sides")
    func binary() {
        let entry = single(PeekEntry(
            id: PeekId("bin"),
            request: PeekRequest(method: "PUT", uri: URL(string: "https://example.com/blob")!, body: .bytes(Data([1, 2, 3]))),
            startedAt: started,
            source: "dio",
            response: PeekResponse(statusCode: 200, body: .bytes(Data([255, 0]), contentType: .octetStream)),
            completedAt: started
        ))
        #expect(entry["request"]?["postData"]?.encoded() == #"{"mimeType":"application/octet-stream","text":"AQID","_encoding":"base64"}"#)
        #expect(entry["response"]?["content"]?.encoded() == #"{"size":2,"mimeType":"application/octet-stream","text":"/wA=","encoding":"base64"}"#)
    }

    @Test("writes form bodies as params")
    func form() {
        let entry = single(PeekEntry(
            id: PeekId("form"),
            request: PeekRequest(
                method: "POST",
                uri: URL(string: "https://example.com/upload")!,
                body: .form(
                    fields: [PeekFormField("album", "Holiday")],
                    files: [PeekFormFile("photo", filename: "beach.jpg", contentType: PeekMediaType(parsing: "image/jpeg")), PeekFormFile("raw")],
                    contentType: .multipartFormData
                )
            ),
            startedAt: started,
            source: "dio",
            response: PeekResponse(statusCode: 204),
            completedAt: started
        ))
        #expect(entry["request"]?["postData"]?.encoded()
            == #"{"mimeType":"multipart/form-data","params":[{"name":"album","value":"Holiday"},{"name":"photo","fileName":"beach.jpg","contentType":"image/jpeg"},{"name":"raw"}]}"#)
        #expect(entry["request"]?["bodySize"]?.encoded() == "-1")
        #expect(entry["response"]?["content"]?.encoded() == #"{"size":0,"mimeType":"x-unknown"}"#)
    }

    @Test("writes failures the way browsers do")
    func failures() {
        let entry = single(QueryFixtures.e5)
        #expect(entry["response"]?.encoded()
            == #"{"status":0,"statusText":"","httpVersion":"HTTP/1.1","cookies":[],"headers":[],"content":{"size":0,"mimeType":"x-unknown"},"redirectURL":"","headersSize":-1,"bodySize":-1}"#)
        #expect(entry["_error"]?.encoded() == #"{"kind":"timeout","message":"slow"}"#)
        #expect(entry["time"]?.encoded() == "5000.0")
        #expect(!single(rich).keys.contains("_error"))
    }

    @Test("marks truncated, missing and remote bodies in comments")
    func comments() {
        let cut = single(with(rich, request: .text("ab", size: 99), response: response(body: .unavailable(.streamed))))
        #expect(cut["request"]?["postData"]?.encoded() == #"{"mimeType":"application/json","text":"ab","comment":"truncated by Peek"}"#)
        #expect(cut["response"]?["content"]?.encoded() == #"{"size":-1,"mimeType":"application/json","comment":"not captured by Peek (streamed)"}"#)
        let remote = single(with(rich, response: response(body: .remote(size: 40))))
        #expect(remote["response"]?["content"]?.encoded() == #"{"size":40,"mimeType":"application/json","comment":"not loaded from the device"}"#)
    }

    @Test("writes valid JSON, compact or pretty")
    func encoding() throws {
        let compact = exporter.export(QueryFixtures.all + [rich])
        let pretty = exporter.export(QueryFixtures.all + [rich], pretty: true)
        #expect(!compact.contains("\n"))
        #expect(pretty.contains("\n  \"log\": {\n"))
        let fromCompact = try JSONSerialization.jsonObject(with: Data(compact.utf8)) as? NSDictionary
        let fromPretty = try JSONSerialization.jsonObject(with: Data(pretty.utf8)) as? NSDictionary
        #expect(fromCompact != nil)
        #expect(fromCompact == fromPretty)
    }

    @Test("escapes strings the way Dart's jsonEncode does")
    func escaping() {
        #expect(JSONValue.string("a\"b\\c\nd\u{1}é/").encoded() == #""a\"b\\c\nd\u0001é/""#)
        #expect(JSONValue.array([]).encoded(pretty: true) == "[]")
        #expect(JSONValue.double(1.5).encoded() == "1.5")
        #expect(JSONValue.double(-1).encoded() == "-1.0")
    }

    @Test("gives every entry the fields HAR 1.2 requires")
    func requiredFields() {
        for entry in entries(QueryFixtures.all + [rich]) {
            #expect(Set(["startedDateTime", "time", "request", "response", "cache", "timings"]).isSubset(of: entry.keys))
            #expect(Set(["method", "url", "httpVersion", "cookies", "headers", "queryString", "headersSize", "bodySize"])
                .isSubset(of: entry["request"]?.keys ?? []))
            #expect(Set(["status", "statusText", "httpVersion", "cookies", "headers", "content", "redirectURL", "headersSize", "bodySize"])
                .isSubset(of: entry["response"]?.keys ?? []))
            #expect(Set(["size", "mimeType"]).isSubset(of: entry["response"]?["content"]?.keys ?? []))
            for key in ["send", "wait", "receive"] {
                let value = entry["timings"]?[key]?.encoded() ?? "-"
                #expect(value.hasSuffix(".0") || value.contains("."))
                #expect(!value.hasPrefix("-"))
            }
        }
    }

    @Test("reads query strings like Dart's Uri")
    func queryParameters() {
        let request = PeekRequest(method: "GET", uri: URL(string: "https://x.dev/?a=1&b=two+words&a=%C3%A9&flag")!)
        #expect(request.queryParameters.map(\.name) == ["a", "b", "flag"])
        #expect(request.queryParameters.map(\.values) == [["1", "é"], ["two words"], [""]])
    }
}
