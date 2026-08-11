import Foundation

// Reading follows Spec/session-format.md: unknown keys are ignored, unknown enum values fall back,
// null reads as absent, and a missing or mistyped required key makes the whole entry unreadable.

nonisolated extension PeekEntry: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, source, startedAt, completedAt, pinned, request, response, failure, timings
    }

    init(json: Data) throws {
        self = try JSONDecoder().decode(PeekEntry.self, from: json)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        guard !id.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "The id is empty.")
        }
        let response = try container.decodeIfPresent(PeekResponse.self, forKey: .response)
        let failure = try container.decodeIfPresent(PeekFailure.self, forKey: .failure)
        let completedAt = try container.decodeTimestampIfPresent(forKey: .completedAt)
        guard (response == nil && failure == nil) == (completedAt == nil) else {
            throw DecodingError.dataCorruptedError(
                forKey: .completedAt, in: container,
                debugDescription: "completedAt goes together with a response or a failure."
            )
        }
        self.init(
            id: PeekId(id),
            request: try container.decode(PeekRequest.self, forKey: .request),
            startedAt: try container.decodeTimestamp(forKey: .startedAt),
            source: try container.decode(String.self, forKey: .source),
            response: response,
            failure: failure,
            completedAt: completedAt,
            isPinned: try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false,
            timings: try container.decodeIfPresent(PeekTimings.self, forKey: .timings)
        )
    }
}

nonisolated extension PeekRequest: Decodable {
    private enum CodingKeys: String, CodingKey {
        case method, url, headers, body, extra
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let extra = try container.decodeIfPresent([String: PeekJSONValue].self, forKey: .extra) ?? [:]
        self.init(
            method: try container.decode(String.self, forKey: .method),
            uri: try container.decodeURL(forKey: .url),
            headers: try container.decodeIfPresent(PeekHeaders.self, forKey: .headers) ?? .empty,
            body: try container.decodeIfPresent(PeekBody.self, forKey: .body) ?? .empty,
            extra: extra.mapValues(\.text)
        )
    }
}

nonisolated extension PeekResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case status, message, headers, body, redirects
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            statusCode: try container.decode(Int.self, forKey: .status),
            statusMessage: try container.decodeIfPresent(String.self, forKey: .message),
            headers: try container.decodeIfPresent(PeekHeaders.self, forKey: .headers) ?? .empty,
            body: try container.decodeIfPresent(PeekBody.self, forKey: .body) ?? .empty,
            redirects: try container.decodeIfPresent([PeekRedirect].self, forKey: .redirects) ?? []
        )
    }
}

nonisolated extension PeekRedirect: Decodable {
    private enum CodingKeys: String, CodingKey {
        case status, method, location
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            statusCode: try container.decode(Int.self, forKey: .status),
            method: try container.decode(String.self, forKey: .method),
            location: try container.decodeURL(forKey: .location)
        )
    }
}

nonisolated extension PeekHeaders: Decodable {
    init(from decoder: any Decoder) throws {
        self.init(try decoder.singleValueContainer().decodePairs())
    }
}

nonisolated extension PeekBody: Decodable {
    private enum CodingKeys: String, CodingKey {
        case kind, type, size, text, bytes, fields, files, reason, truncated
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = PeekMediaType(parsing: try container.decodeIfPresent(String.self, forKey: .type))
        let size = try container.decodeIfPresent(Int.self, forKey: .size)
        switch try container.decode(String.self, forKey: .kind) {
        case "empty":
            self = .empty
        case "text":
            self = .text(try container.decode(String.self, forKey: .text), contentType: type, size: size)
        case "bytes":
            let encoded = try container.decode(String.self, forKey: .bytes)
            guard let data = Data(base64Encoded: encoded) else {
                throw DecodingError.dataCorruptedError(forKey: .bytes, in: container, debugDescription: "Not base64.")
            }
            self = .bytes(data, contentType: type, size: size)
        case "form":
            let fields = try container.decodeIfPresent(PeekFormFields.self, forKey: .fields)?.fields ?? []
            let files = try container.decodeIfPresent([PeekFormFile].self, forKey: .files) ?? []
            self = .form(fields: fields, files: files, contentType: type)
        case "unavailable":
            let reason = (try? container.decodeIfPresent(String.self, forKey: .reason))
                .flatMap(PeekBodyUnavailableReason.init(rawValue:))
            self = .unavailable(reason ?? .notCaptured, contentType: type, size: size)
        case "remote":
            let isTruncated = try container.decodeIfPresent(Bool.self, forKey: .truncated) ?? false
            self = .remote(size: try container.decode(Int.self, forKey: .size), contentType: type, isTruncated: isTruncated)
        default:
            // A kind from a newer writer: the body exists, but not in a form this reader holds.
            self = .unavailable(.notCaptured, contentType: type, size: size)
        }
    }
}

nonisolated extension PeekFormFile: Decodable {
    private enum CodingKeys: String, CodingKey {
        case name, filename, type, size
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            try container.decode(String.self, forKey: .name),
            filename: try container.decodeIfPresent(String.self, forKey: .filename),
            contentType: PeekMediaType(parsing: try container.decodeIfPresent(String.self, forKey: .type)),
            size: try container.decodeIfPresent(Int.self, forKey: .size)
        )
    }
}

nonisolated extension PeekFailure: Decodable {
    private enum CodingKeys: String, CodingKey {
        case kind, message, details, stackTrace
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = (try? container.decodeIfPresent(String.self, forKey: .kind))
            .flatMap(PeekFailureKind.init(rawValue:))
        self.init(
            kind: kind ?? .unknown,
            message: try container.decode(String.self, forKey: .message),
            details: try container.decodeIfPresent(String.self, forKey: .details),
            stackTrace: try container.decodeIfPresent(String.self, forKey: .stackTrace)
        )
    }
}

nonisolated extension PeekTimings: Decodable {
    private enum CodingKeys: String, CodingKey {
        case blocked, dns, connect, ssl, send, wait, receive
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func duration(_ key: CodingKeys) throws -> Duration? {
            try container.decodeIfPresent(Double.self, forKey: key)
                .map { .microseconds(Int64(($0 * 1000).rounded())) }
        }
        self.init(
            blocked: try duration(.blocked),
            dns: try duration(.dns),
            connect: try duration(.connect),
            ssl: try duration(.ssl),
            send: try duration(.send),
            wait: try duration(.wait),
            receive: try duration(.receive)
        )
    }
}

private nonisolated struct PeekFormFields: Decodable {
    let fields: [PeekFormField]

    init(from decoder: any Decoder) throws {
        fields = try decoder.singleValueContainer().decodePairs().map { PeekFormField($0.0, $0.1) }
    }
}

/// Any JSON value, kept for `PeekRequest.extra`, whose values the model holds as text.
private nonisolated enum PeekJSONValue: Decodable {
    case string(String)
    case bool(Bool)
    case integer(Int)
    case number(Double)
    case array([PeekJSONValue])
    case object([String: PeekJSONValue])
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([PeekJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: PeekJSONValue].self))
        }
    }

    /// A string as it is, anything else as compact JSON.
    var text: String {
        if case .string(let value) = self { return value }
        return json
    }

    private var json: String {
        switch self {
        case .string(let value):
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            let data = (try? encoder.encode(value)) ?? Data()
            return String(decoding: data, as: UTF8.self)
        case .bool(let value): return value ? "true" : "false"
        case .integer(let value): return String(value)
        case .number(let value): return String(value)
        case .null: return "null"
        case .array(let values): return "[" + values.map(\.json).joined(separator: ",") + "]"
        case .object(let values):
            let members = values.sorted { $0.key < $1.key }
                .map { PeekJSONValue.string($0.key).json + ":" + $0.value.json }
            return "{" + members.joined(separator: ",") + "}"
        }
    }
}

private nonisolated extension SingleValueDecodingContainer {
    func decodePairs() throws -> [(String, String)] {
        try decode([[String]].self).map { pair in
            guard pair.count == 2 else {
                throw DecodingError.dataCorruptedError(in: self, debugDescription: "Expected a [name, value] pair.")
            }
            return (pair[0], pair[1])
        }
    }
}

private nonisolated extension KeyedDecodingContainer {
    func decodeTimestamp(forKey key: Key) throws -> Date {
        let text = try decode(String.self, forKey: key)
        guard let date = PeekTimestamp.parse(text) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Not an ISO 8601 time: \(text)")
        }
        return date
    }

    func decodeTimestampIfPresent(forKey key: Key) throws -> Date? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeTimestamp(forKey: key)
    }

    func decodeURL(forKey key: Key) throws -> URL {
        let text = try decode(String.self, forKey: key)
        guard let url = URL(string: text) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Not a URL: \(text)")
        }
        return url
    }
}
