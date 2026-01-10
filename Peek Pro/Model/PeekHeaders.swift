import Foundation

nonisolated struct PeekHeaders: Hashable, Sendable, ExpressibleByDictionaryLiteral {
    nonisolated struct Field: Hashable, Sendable {
        let name: String
        let values: [String]
    }

    static let empty = PeekHeaders([])

    let fields: [Field]

    init(_ pairs: [(String, String)]) {
        var order: [String] = []
        var collected: [String: Field] = [:]
        for (rawName, rawValue) in pairs {
            let name = rawName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            let value = rawValue.trimmingCharacters(in: .whitespaces)
            if let existing = collected[key] {
                collected[key] = Field(name: existing.name, values: existing.values + [value])
            } else {
                order.append(key)
                collected[key] = Field(name: name, values: [value])
            }
        }
        fields = order.compactMap { collected[$0] }
    }

    init(dictionaryLiteral elements: (String, String)...) {
        self.init(elements)
    }

    var count: Int { fields.count }
    var isEmpty: Bool { fields.isEmpty }
    var names: [String] { fields.map(\.name) }

    var entries: [(name: String, value: String)] {
        fields.flatMap { field in field.values.map { (name: field.name, value: $0) } }
    }

    subscript(name: String) -> String? {
        field(named: name)?.values.joined(separator: ", ")
    }

    func values(of name: String) -> [String] {
        field(named: name)?.values ?? []
    }

    func contains(_ name: String) -> Bool {
        field(named: name) != nil
    }

    var contentType: String? { self["content-type"] }
    var contentLength: Int? { values(of: "content-length").first.flatMap(Int.init) }

    var cookies: [PeekCookie] {
        values(of: "cookie").flatMap(PeekCookie.parseCookieHeader)
    }

    var setCookies: [PeekCookie] {
        values(of: "set-cookie").compactMap(PeekCookie.parseSetCookie)
    }

    /// Size on the wire as `Name: value\r\n` lines — HTTP/2 compresses them, so it is an estimate.
    var byteCount: Int {
        entries.reduce(0) { $0 + $1.name.utf8.count + $1.value.utf8.count + 4 }
    }

    private func field(named name: String) -> Field? {
        let key = name.lowercased()
        return fields.first { $0.name.lowercased() == key }
    }
}
