import Foundation

/// Mirrors `PeekHarExporter` from Peek core: entries as an HTTP Archive (HAR 1.2) document.
///
/// Pending calls are left out — HAR has no notion of a call without an outcome. Failed calls are written the way
/// browsers do it: status `0` and an `_error` field. Other fields starting with `_` are Peek's own and HAR readers
/// ignore them. The creator is Peek Pro with its own version, where Peek writes itself.
nonisolated struct PeekHarExporter: Sendable {
    static let creatorName = "Peek Pro"

    var creatorVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    func export(_ entries: [PeekEntry], pretty: Bool = false) -> String {
        toJSON(entries).encoded(pretty: pretty)
    }

    func toJSON(_ entries: [PeekEntry]) -> JSONValue {
        jsonObject([
            ("log", jsonObject([
                ("version", .string("1.2")),
                ("creator", jsonObject([("name", .string(Self.creatorName)), ("version", .string(creatorVersion))])),
                ("entries", .array(entries.filter { $0.state != .pending }.map(entry))),
            ])),
        ])
    }

    private func entry(_ entry: PeekEntry) -> JSONValue {
        let timings = Self.timings(entry.timings, total: Self.millis(entry.duration ?? .zero))
        return jsonObject([
            ("startedDateTime", .string(PeekExportFormat.timestamp(entry.startedAt))),
            ("time", .double(Self.total(timings))),
            ("request", request(entry.request)),
            ("response", response(entry.response)),
            ("cache", .object([])),
            ("timings", jsonObject(timings.map { ($0.name, JSONValue.double($0.value) as JSONValue?) })),
            ("_error", entry.failure.map { jsonObject([("kind", .string($0.kind.rawValue)), ("message", .string($0.message))]) }),
            ("_peek", jsonObject([("id", .string(entry.id.value)), ("source", .string(entry.source))])),
        ])
    }

    private func request(_ request: PeekRequest) -> JSONValue {
        jsonObject([
            ("method", .string(request.method)),
            ("url", .string(request.uri.absoluteString)),
            ("httpVersion", .string("HTTP/1.1")),
            ("cookies", .array(request.headers.cookies.map(Self.cookie))),
            ("headers", Self.headers(request.headers)),
            ("queryString", .array(request.queryParameters.flatMap { parameter in
                parameter.values.map { jsonObject([("name", .string(parameter.name)), ("value", .string($0))]) }
            })),
            ("postData", postData(request)),
            ("headersSize", .int(-1)),
            ("bodySize", .int(request.contentLength ?? -1)),
        ])
    }

    private func postData(_ request: PeekRequest) -> JSONValue? {
        let mimeType = JSONValue.string(request.mediaType?.mimeType ?? "application/octet-stream")
        let body = request.body
        switch body {
        case .text(let text, _, _):
            return jsonObject([
                ("mimeType", mimeType),
                ("text", .string(text)),
                ("comment", body.isTruncated ? .string("truncated by Peek") : nil),
            ])
        case .bytes(let data, _, _):
            return jsonObject([("mimeType", mimeType), ("text", .string(data.base64EncodedString())), ("_encoding", .string("base64"))])
        case .form(let fields, let files, _):
            let params = fields.map { jsonObject([("name", .string($0.name)), ("value", .string($0.value))]) }
                + files.map { file in
                    jsonObject([
                        ("name", .string(file.name)),
                        ("fileName", file.filename.map(JSONValue.string)),
                        ("contentType", file.contentType.map { .string($0.description) }),
                    ])
                }
            return jsonObject([("mimeType", mimeType), ("params", .array(params))])
        case .empty, .unavailable, .remote:
            return nil
        }
    }

    private func response(_ response: PeekResponse?) -> JSONValue {
        guard let response else {
            return jsonObject([
                ("status", .int(0)),
                ("statusText", .string("")),
                ("httpVersion", .string("HTTP/1.1")),
                ("cookies", .array([])),
                ("headers", .array([])),
                ("content", jsonObject([("size", .int(0)), ("mimeType", .string("x-unknown"))])),
                ("redirectURL", .string("")),
                ("headersSize", .int(-1)),
                ("bodySize", .int(-1)),
            ])
        }
        return jsonObject([
            ("status", .int(response.statusCode)),
            ("statusText", .string(response.statusMessage ?? "")),
            ("httpVersion", .string("HTTP/1.1")),
            ("cookies", .array(response.headers.setCookies.map(Self.cookie))),
            ("headers", Self.headers(response.headers)),
            ("content", content(response)),
            ("redirectURL", .string(response.headers["location"] ?? "")),
            ("headersSize", .int(-1)),
            ("bodySize", .int(response.contentLength ?? -1)),
        ])
    }

    private func content(_ response: PeekResponse) -> JSONValue {
        let body = response.body
        let truncated: JSONValue? = body.isTruncated ? .string("truncated by Peek") : nil
        var members: [(String, JSONValue?)] = [
            ("size", .int(body.size ?? -1)),
            ("mimeType", .string(response.mediaType?.mimeType ?? "x-unknown")),
        ]
        switch body {
        case .text(let text, _, _):
            members += [("text", .string(text)), ("comment", truncated)]
        case .bytes(let data, _, _):
            members += [("text", .string(data.base64EncodedString())), ("encoding", .string("base64")), ("comment", truncated)]
        case .unavailable(let reason, _, _):
            members.append(("comment", .string("not captured by Peek (\(reason.rawValue))")))
        case .remote:
            // Peek Pro only: the body stayed on the device and was never loaded.
            members.append(("comment", .string("not loaded from the device")))
        case .form, .empty:
            break
        }
        return jsonObject(members)
    }

    private static func timings(_ timings: PeekTimings?, total: Double) -> [(name: String, value: Double)] {
        let blocked = millisOrNone(timings?.blocked)
        let dns = millisOrNone(timings?.dns)
        let connect = millisOrNone(timings?.connect)
        let send = millis(timings?.send ?? .zero)
        let receive = millis(timings?.receive ?? .zero)
        let measured = Self.total([("blocked", blocked), ("dns", dns), ("connect", connect), ("send", send), ("receive", receive)])
        // Whatever the named phases leave over was spent waiting.
        let wait = timings?.wait.map(millis) ?? max(total - measured, 0)
        return [
            ("blocked", blocked), ("dns", dns), ("connect", connect), ("ssl", millisOrNone(timings?.ssl)),
            ("send", send), ("wait", wait), ("receive", receive),
        ]
    }

    /// The elapsed time HAR expects beside the phases: their sum, with `ssl` left out — it's inside `connect`.
    private static func total(_ timings: [(name: String, value: Double)]) -> Double {
        timings.filter { $0.name != "ssl" && $0.value >= 0 }.reduce(0) { $0 + $1.value }
    }

    private static func headers(_ headers: PeekHeaders) -> JSONValue {
        .array(headers.entries.map { jsonObject([("name", .string($0.name)), ("value", .string($0.value))]) })
    }

    private static func cookie(_ cookie: PeekCookie) -> JSONValue {
        jsonObject([
            ("name", .string(cookie.name)),
            ("value", .string(cookie.value)),
            ("path", cookie.path.map(JSONValue.string)),
            ("domain", cookie.domain.map(JSONValue.string)),
            ("expires", cookie.expiresAt.map { .string(PeekExportFormat.timestamp($0)) }),
            ("httpOnly", .bool(cookie.isHttpOnly)),
            ("secure", .bool(cookie.isSecure)),
        ])
    }

    private static func millis(_ duration: Duration) -> Double {
        Double(duration.inMicroseconds) / 1_000
    }

    private static func millisOrNone(_ duration: Duration?) -> Double {
        duration.map(millis) ?? -1
    }
}
