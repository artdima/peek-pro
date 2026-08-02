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

    /// `Expires` read as an IMF-fixdate (`Wed, 21 Oct 2015 07:28:00 GMT`), as Peek reads it; other forms give `nil`.
    var expiresAt: Date? {
        guard let raw = expires?.trimmingCharacters(in: .whitespaces) else { return nil }
        let parts = raw.split(whereSeparator: \.isWhitespace)
        guard parts.count == 6, parts[0].count == 4, parts[0].last == ",", parts[0].dropLast().allSatisfy(\.isLetter),
              parts[5] == "GMT",
              (1...2).contains(parts[1].count), let day = Int(parts[1]),
              let monthIndex = Self.months.firstIndex(of: parts[2].lowercased()),
              parts[3].count == 4, let year = Int(parts[3])
        else { return nil }
        let clock = parts[4].split(separator: ":", omittingEmptySubsequences: false)
        guard clock.count == 3, (1...2).contains(clock[0].count), clock[1].count == 2, clock[2].count == 2,
              let hour = Int(clock[0]), let minute = Int(clock[1]), let second = Int(clock[2])
        else { return nil }
        let components = DateComponents(year: year, month: monthIndex + 1, day: day, hour: hour, minute: minute, second: second)
        return Calendar.utc.date(from: components)
    }

    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

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
