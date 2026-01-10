import Foundation

nonisolated struct PeekCookie: Hashable, Sendable {
    nonisolated struct Attribute: Hashable, Sendable {
        let name: String
        let value: String?
    }

    let name: String
    let value: String
    let attributes: [Attribute]

    init(name: String, value: String, attributes: [Attribute] = []) {
        self.name = name
        self.value = value
        self.attributes = attributes
    }

    static func parseCookieHeader(_ header: String) -> [PeekCookie] {
        header.split(separator: ";").compactMap { part in
            Self.split(part).map { PeekCookie(name: $0.name, value: $0.value ?? "") }
        }
    }

    static func parseSetCookie(_ header: String) -> PeekCookie? {
        let parts = header.split(separator: ";", omittingEmptySubsequences: false)
        guard let first = parts.first, let pair = Self.split(first), let value = pair.value else { return nil }
        let attributes = parts.dropFirst().compactMap { part in
            Self.split(part).map { Attribute(name: $0.name.lowercased(), value: $0.value) }
        }
        return PeekCookie(name: pair.name, value: value, attributes: attributes)
    }

    func attribute(_ name: String) -> String? {
        attributes.first { $0.name == name }?.value
    }

    var path: String? { attribute("path") }
    var domain: String? { attribute("domain") }
    var expires: String? { attribute("expires") }
    var maxAge: Int? { attribute("max-age").flatMap(Int.init) }
    var sameSite: String? { attribute("samesite") }
    var isSecure: Bool { attributes.contains { $0.name == "secure" } }
    var isHttpOnly: Bool { attributes.contains { $0.name == "httponly" } }

    private static func split(_ part: Substring) -> (name: String, value: String?)? {
        let trimmed = part.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let separator = trimmed.firstIndex(of: "=") else { return (trimmed, nil) }
        let name = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        return (name, value)
    }
}
