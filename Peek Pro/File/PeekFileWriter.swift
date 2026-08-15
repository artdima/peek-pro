import Foundation

/// Writes a `.peek` session exactly as Peek's `PeekSessionCodec` does — same keys, same order, same numbers —
/// so a file saved here reads the same in Peek and diffs cleanly against one Peek wrote.
///
/// Two things can't come back as they were read: `extra` values that weren't strings are written as strings
/// (the model keeps them as text), and `extra` keys are sorted. A body still on the device keeps its
/// `remote` marker, as Peek writes it; a file can't fetch it, so the viewer says it wasn't saved.
nonisolated enum PeekFileWriter {
    static let formatVersion = 1

    static func write(info: PeekSessionInfo, entries: [PeekEntry], to url: URL) throws {
        try data(info: info, entries: entries).write(to: url, options: .atomic)
    }

    static func data(info: PeekSessionInfo, entries: [PeekEntry]) -> Data {
        var text = headerLine(info) + "\n"
        for entry in entries {
            text += entryLine(entry) + "\n"
        }
        return Data(text.utf8)
    }

    static func headerLine(_ info: PeekSessionInfo) -> String {
        jsonObject([("format", .string("peek")), ("formatVersion", .int(formatVersion))] + sessionMembers(info)).encoded()
    }

    /// What a `hello` frame says about the app — the header without its format keys.
    static func encode(_ info: PeekSessionInfo) -> JSONValue {
        jsonObject(sessionMembers(info))
    }

    private static func sessionMembers(_ info: PeekSessionInfo) -> [(String, JSONValue?)] {
        [
            ("peekVersion", .string(info.peekVersion)),
            ("name", info.name.map(JSONValue.string)),
            ("platform", .string(info.platform.rawValue)),
            ("osVersion", info.osVersion.map(JSONValue.string)),
            ("startedAt", .string(PeekExportFormat.timestamp(info.startedAt))),
        ]
    }

    static func entryLine(_ entry: PeekEntry) -> String {
        encode(entry).encoded()
    }

    static func encode(_ entry: PeekEntry) -> JSONValue {
        jsonObject([
            ("id", .string(entry.id.value)),
            ("source", .string(entry.source)),
            ("startedAt", .string(PeekExportFormat.timestamp(entry.startedAt))),
            ("completedAt", entry.completedAt.map { .string(PeekExportFormat.timestamp($0)) }),
            ("pinned", entry.isPinned ? .bool(true) : nil),
            ("request", encode(entry.request)),
            ("response", entry.response.map { encode($0) }),
            ("failure", entry.failure.map { encode($0) }),
            ("timings", entry.timings.map { encode($0) }),
        ])
    }

    private static func encode(_ request: PeekRequest) -> JSONValue {
        jsonObject([
            ("method", .string(request.method)),
            ("url", .string(request.uri.absoluteString)),
            ("headers", request.headers.isEmpty ? nil : encode(request.headers)),
            ("body", request.body == .empty ? nil : encode(request.body)),
            ("extra", request.extra.isEmpty ? nil : jsonObject(request.extra.sorted { $0.key < $1.key }.map { ($0.key, JSONValue.string($0.value) as JSONValue?) })),
        ])
    }

    private static func encode(_ response: PeekResponse) -> JSONValue {
        jsonObject([
            ("status", .int(response.statusCode)),
            ("message", response.statusMessage.map(JSONValue.string)),
            ("headers", response.headers.isEmpty ? nil : encode(response.headers)),
            ("body", response.body == .empty ? nil : encode(response.body)),
            ("redirects", response.redirects.isEmpty ? nil : .array(response.redirects.map { redirect in
                jsonObject([
                    ("status", .int(redirect.statusCode)),
                    ("method", .string(redirect.method)),
                    ("location", .string(redirect.location.absoluteString)),
                ])
            })),
        ])
    }

    private static func encode(_ headers: PeekHeaders) -> JSONValue {
        JSONValue.array(headers.entries.map { JSONValue.array([.string($0.name), .string($0.value)]) })
    }

    static func encode(_ body: PeekBody) -> JSONValue {
        var members: [(String, JSONValue?)]
        switch body {
        case .empty:
            members = [("kind", .string("empty"))]
        case .text(let text, _, _):
            members = [("kind", .string("text")), ("text", .string(text)), ("size", body.isTruncated ? body.size.map(JSONValue.int) : nil)]
        case .bytes(let data, _, _):
            members = [("kind", .string("bytes")), ("bytes", .string(data.base64EncodedString())), ("size", body.isTruncated ? body.size.map(JSONValue.int) : nil)]
        case .form(let fields, let files, _):
            members = [
                ("kind", .string("form")),
                ("fields", fields.isEmpty ? nil : JSONValue.array(fields.map { JSONValue.array([.string($0.name), .string($0.value)]) })),
                ("files", files.isEmpty ? nil : .array(files.map { file in
                    jsonObject([
                        ("name", .string(file.name)),
                        ("filename", file.filename.map(JSONValue.string)),
                        ("type", file.contentType.map { .string($0.description) }),
                        ("size", file.size.map(JSONValue.int)),
                    ])
                })),
            ]
        case .unavailable(let reason, _, let size):
            members = [("kind", .string("unavailable")), ("reason", .string(reason.rawValue)), ("size", size.map(JSONValue.int))]
        case .remote(let size, _, let isTruncated):
            members = [("kind", .string("remote")), ("size", .int(size)), ("truncated", isTruncated ? .bool(true) : nil)]
        }
        members.append(("type", body.contentType.map { .string($0.description) }))
        return jsonObject(members)
    }

    private static func encode(_ failure: PeekFailure) -> JSONValue {
        jsonObject([
            ("kind", .string(failure.kind.rawValue)),
            ("message", .string(failure.message)),
            ("details", failure.details.map(JSONValue.string)),
            ("stackTrace", failure.stackTrace.map(JSONValue.string)),
        ])
    }

    /// Whole milliseconds as integers, the rest with their fraction — as Peek writes them.
    private static func encode(_ timings: PeekTimings) -> JSONValue {
        jsonObject(timings.known.map { known -> (String, JSONValue?) in
            let micros = known.duration.inMicroseconds
            let value: JSONValue = micros % 1_000 == 0 ? .int(Int(micros / 1_000)) : .number("\(Double(micros) / 1_000)")
            return (known.phase.rawValue, value)
        })
    }
}
