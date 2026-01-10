import Foundation

nonisolated struct PeekMediaType: Hashable, Sendable, CustomStringConvertible {
    static let json = PeekMediaType("application", "json")
    static let plainText = PeekMediaType("text", "plain")
    static let html = PeekMediaType("text", "html")
    static let octetStream = PeekMediaType("application", "octet-stream")
    static let formUrlEncoded = PeekMediaType("application", "x-www-form-urlencoded")
    static let multipartFormData = PeekMediaType("multipart", "form-data")

    let type: String
    let subtype: String
    let parameters: [String: String]

    init(_ type: String, _ subtype: String, parameters: [String: String] = [:]) {
        self.type = type.trimmingCharacters(in: .whitespaces).lowercased()
        self.subtype = subtype.trimmingCharacters(in: .whitespaces).lowercased()
        self.parameters = Dictionary(
            parameters.map { ($0.key.trimmingCharacters(in: .whitespaces).lowercased(), $0.value) },
            uniquingKeysWith: { _, last in last }
        )
    }

    init?(parsing value: String?) {
        guard let value else { return nil }
        let parts = value.split(separator: ";", omittingEmptySubsequences: false)
        guard let first = parts.first else { return nil }
        let mimeType = first.trimmingCharacters(in: .whitespaces)
        let pieces = mimeType.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2, !pieces[0].isEmpty, !pieces[1].isEmpty,
              !mimeType.contains(where: \.isWhitespace)
        else { return nil }
        var parameters: [String: String] = [:]
        for part in parts.dropFirst() {
            guard let separator = part.firstIndex(of: "=") else { continue }
            let name = part[..<separator].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let raw = part[part.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            parameters[name] = Self.unquote(raw)
        }
        self.init(String(pieces[0]), String(pieces[1]), parameters: parameters)
    }

    var mimeType: String { "\(type)/\(subtype)" }
    var charset: String? { parameters["charset"]?.lowercased() }

    var isJson: Bool { subtype == "json" || subtype.hasSuffix("+json") }
    var isXml: Bool { subtype == "xml" || subtype.hasSuffix("+xml") }
    var isHtml: Bool { mimeType == "text/html" || mimeType == "application/xhtml+xml" }
    var isImage: Bool { type == "image" }
    var isFormUrlEncoded: Bool { mimeType == "application/x-www-form-urlencoded" }
    var isMultipart: Bool { type == "multipart" }

    var isText: Bool {
        type == "text" || isJson || isXml || isFormUrlEncoded
            || Self.textualApplicationSubtypes.contains(subtype)
    }

    var description: String {
        let pairs = parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        return ([mimeType] + pairs).joined(separator: "; ")
    }

    private static let textualApplicationSubtypes: Set<String> = [
        "javascript", "ecmascript", "graphql", "x-ndjson", "yaml", "x-yaml", "toml", "sql",
    ]

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return value }
        return String(value.dropFirst().dropLast())
    }
}
