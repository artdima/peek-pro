import Foundation

/// Mirrors the frames of Peek's remote protocol (`doc/spec/remote-protocol.md`): one WebSocket text message,
/// one JSON object with a `type`. Entries and bodies inside are written as a `.peek` file writes them.
nonisolated enum PeekRemoteFrame: Hashable, Sendable {
    /// App → desktop, first on every connection.
    case hello(PeekRemoteHello)
    /// Desktop → app.
    case welcome(protocolVersion: Int = PeekRemoteProtocol.version, serverName: String? = nil, serverVersion: String? = nil)
    /// Desktop → app, then the desktop closes.
    case denied(PeekRemoteDeniedReason, message: String)
    case entryAdded(PeekEntry)
    case entryUpdated(PeekEntry)
    case entryRemoved(PeekId)
    case cleared
    /// The history after a welcome ends here.
    case synced(count: Int)
    /// The app threw this many frames away.
    case dropped(count: Int)
    /// Desktop → app.
    case bodyRequest(requestID: String, entryID: PeekId, side: PeekBodySide)
    case bodyResponse(requestID: String, body: PeekBody)
    case bodyError(requestID: String, error: PeekRemoteBodyError, message: String?)
    case ping
    case pong
    /// From a newer peer; ignored, as the protocol asks.
    case unknown(type: String)
}

nonisolated struct PeekRemoteHello: Hashable, Sendable {
    var protocolVersion: Int
    var token: String?
    /// The same across reconnections while the app runs.
    var sessionID: String
    var info: PeekSessionInfo

    init(protocolVersion: Int = PeekRemoteProtocol.version, token: String?, sessionID: String, info: PeekSessionInfo) {
        self.protocolVersion = protocolVersion
        self.token = token
        self.sessionID = sessionID
        self.info = info
    }
}

nonisolated enum PeekRemoteDeniedReason: String, Hashable, Sendable {
    case token
    case protocolVersion
    case other
}

nonisolated enum PeekRemoteBodyError: String, Hashable, Sendable {
    case notFound
    case notHeld
    case failed
}

nonisolated enum PeekRemoteProtocol {
    static let version = 1
    static let defaultPort = 9741

    /// `nil` to welcome the app, or the refusal to send — the version first, then the token, as Peek's
    /// `PeekRemoteProtocol.check` decides it.
    static func check(_ hello: PeekRemoteHello, token: String?, oldest: Int = version, newest: Int = version) -> PeekRemoteFrame? {
        let spoken = hello.protocolVersion
        if spoken < oldest || spoken > newest {
            let range = oldest == newest ? "\(newest)" : "\(oldest) to \(newest)"
            let side = spoken < oldest ? "Peek in the app" : "the desktop"
            return .denied(.protocolVersion, message: "The app speaks protocol \(spoken), this desktop \(range). Update \(side).")
        }
        if let token, !sameToken(hello.token, token) {
            return .denied(.token, message: "The token does not match the one the desktop shows.")
        }
        return nil
    }

    /// Looks at every character, so the time taken says nothing about how much of a guess was right.
    private static func sameToken(_ given: String?, _ expected: String) -> Bool {
        guard let given else { return false }
        let left = Array(given.utf8)
        let right = Array(expected.utf8)
        guard left.count == right.count else { return false }
        return zip(left, right).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

// MARK: - Reading

nonisolated extension PeekRemoteFrame {
    /// Reads one message. Unknown keys are ignored, unknown enum values read as their fallback and an unknown `type`
    /// reads as `.unknown`; text that isn't a frame throws — the caller drops it and keeps the connection.
    init(text: String) throws {
        self = try JSONDecoder().decode(Frame.self, from: Data(text.utf8)).frame
    }

    private nonisolated struct Frame: Decodable {
        let frame: PeekRemoteFrame

        private enum CodingKeys: String, CodingKey {
            case type, protocolVersion, token, sessionId, session, server, reason, message
            case op, entry, id, count, requestId, side, body, error
        }

        private enum ServerKeys: String, CodingKey {
            case name, version
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "hello":
                frame = .hello(PeekRemoteHello(
                    protocolVersion: try container.decode(Int.self, forKey: .protocolVersion),
                    token: try container.decodeIfPresent(String.self, forKey: .token),
                    sessionID: try container.decode(String.self, forKey: .sessionId),
                    info: try container.decode(PeekSessionInfo.self, forKey: .session)
                ))
            case "welcome":
                let server = try? container.nestedContainer(keyedBy: ServerKeys.self, forKey: .server)
                frame = .welcome(
                    protocolVersion: try container.decode(Int.self, forKey: .protocolVersion),
                    serverName: try server?.decodeIfPresent(String.self, forKey: .name),
                    serverVersion: try server?.decodeIfPresent(String.self, forKey: .version)
                )
            case "denied":
                let reason = try container.decodeIfPresent(String.self, forKey: .reason).flatMap(PeekRemoteDeniedReason.init(rawValue:))
                frame = .denied(reason ?? .other, message: try container.decodeIfPresent(String.self, forKey: .message) ?? "")
            case "entry":
                switch try container.decode(String.self, forKey: .op) {
                case "add": frame = .entryAdded(try container.decode(PeekEntry.self, forKey: .entry))
                case "update": frame = .entryUpdated(try container.decode(PeekEntry.self, forKey: .entry))
                case "remove": frame = .entryRemoved(PeekId(try container.decode(String.self, forKey: .id)))
                case let op:
                    throw DecodingError.dataCorruptedError(forKey: .op, in: container, debugDescription: "\(op) is not an entry operation")
                }
            case "cleared":
                frame = .cleared
            case "synced":
                frame = .synced(count: try container.decode(Int.self, forKey: .count))
            case "dropped":
                frame = .dropped(count: try container.decode(Int.self, forKey: .count))
            case "bodyRequest":
                let sideText = try container.decode(String.self, forKey: .side)
                guard let side = PeekBodySide(rawValue: sideText) else {
                    throw DecodingError.dataCorruptedError(forKey: .side, in: container, debugDescription: "\(sideText) is not a body side")
                }
                frame = .bodyRequest(
                    requestID: try container.decode(String.self, forKey: .requestId),
                    entryID: PeekId(try container.decode(String.self, forKey: .id)),
                    side: side
                )
            case "bodyResponse":
                let requestID = try container.decode(String.self, forKey: .requestId)
                if let body = try container.decodeIfPresent(PeekBody.self, forKey: .body) {
                    frame = .bodyResponse(requestID: requestID, body: body)
                } else {
                    let error = try container.decodeIfPresent(String.self, forKey: .error).flatMap(PeekRemoteBodyError.init(rawValue:))
                    frame = .bodyError(
                        requestID: requestID,
                        error: error ?? .failed,
                        message: try container.decodeIfPresent(String.self, forKey: .message)
                    )
                }
            case "ping":
                frame = .ping
            case "pong":
                frame = .pong
            default:
                frame = .unknown(type: type)
            }
        }
    }
}

// MARK: - Writing

nonisolated extension PeekRemoteFrame {
    /// One message, keys in the order Peek writes them, so a frame reads the same from either end.
    var text: String { json.encoded() }

    var json: JSONValue {
        switch self {
        case .hello(let hello):
            jsonObject([
                ("type", .string("hello")),
                ("protocolVersion", .int(hello.protocolVersion)),
                ("token", hello.token.map(JSONValue.string)),
                ("sessionId", .string(hello.sessionID)),
                ("session", PeekFileWriter.encode(hello.info)),
            ])
        case .welcome(let version, let name, let serverVersion):
            jsonObject([
                ("type", .string("welcome")),
                ("protocolVersion", .int(version)),
                ("server", name == nil && serverVersion == nil ? nil : jsonObject([
                    ("name", name.map(JSONValue.string)),
                    ("version", serverVersion.map(JSONValue.string)),
                ])),
            ])
        case .denied(let reason, let message):
            jsonObject([("type", .string("denied")), ("reason", .string(reason.rawValue)), ("message", .string(message))])
        case .entryAdded(let entry):
            Self.entry("add", PeekFileWriter.encode(entry))
        case .entryUpdated(let entry):
            Self.entry("update", PeekFileWriter.encode(entry))
        case .entryRemoved(let id):
            jsonObject([("type", .string("entry")), ("op", .string("remove")), ("id", .string(id.value))])
        case .cleared:
            jsonObject([("type", .string("cleared"))])
        case .synced(let count):
            jsonObject([("type", .string("synced")), ("count", .int(count))])
        case .dropped(let count):
            jsonObject([("type", .string("dropped")), ("count", .int(count))])
        case .bodyRequest(let requestID, let entryID, let side):
            jsonObject([
                ("type", .string("bodyRequest")),
                ("requestId", .string(requestID)),
                ("id", .string(entryID.value)),
                ("side", .string(side.rawValue)),
            ])
        case .bodyResponse(let requestID, let body):
            jsonObject([("type", .string("bodyResponse")), ("requestId", .string(requestID)), ("body", PeekFileWriter.encode(body))])
        case .bodyError(let requestID, let error, let message):
            jsonObject([
                ("type", .string("bodyResponse")),
                ("requestId", .string(requestID)),
                ("error", .string(error.rawValue)),
                ("message", message.map(JSONValue.string)),
            ])
        case .ping:
            jsonObject([("type", .string("ping"))])
        case .pong:
            jsonObject([("type", .string("pong"))])
        case .unknown(let type):
            jsonObject([("type", .string(type))])
        }
    }

    private static func entry(_ op: String, _ entry: JSONValue) -> JSONValue {
        jsonObject([("type", .string("entry")), ("op", .string(op)), ("entry", entry)])
    }
}
