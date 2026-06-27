import Foundation

nonisolated enum PeekSearchScope: String, CaseIterable, Sendable {
    case url
    case headers
    case requestBody
    case responseBody
    case error
}

/// Mirrors `PeekSearchQuery` from Peek core: case-insensitive and literal.
/// Every searched string is cut to `maxBodyLength` characters so typing stays responsive with large bodies in memory.
nonisolated struct PeekSearchQuery: Hashable, Sendable {
    static let none = PeekSearchQuery("")

    var text: String
    var scopes: Set<PeekSearchScope>
    var maxBodyLength: Int

    init(_ text: String, scopes: Set<PeekSearchScope> = Set(PeekSearchScope.allCases), maxBodyLength: Int = 64 * 1_024) {
        self.text = text
        self.scopes = scopes
        self.maxBodyLength = maxBodyLength
    }

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isEmpty: Bool { trimmedText.isEmpty || scopes.isEmpty }

    func matches(_ entry: PeekEntry) -> Bool { compile()(entry) }

    /// Builds the matcher once; use it to test many entries.
    func compile() -> @Sendable (PeekEntry) -> Bool {
        guard !isEmpty else { return { _ in true } }
        let needle = trimmedText
        let scopes = self.scopes
        let limit = maxBodyLength
        return { entry in
            let has: (String?) -> Bool = { haystack in
                guard let haystack else { return false }
                return haystack.prefix(limit).range(of: needle, options: .caseInsensitive) != nil
            }
            if scopes.contains(.url), has(entry.request.uri.absoluteString) { return true }
            if scopes.contains(.headers),
               Self.inHeaders(entry.request.headers, has) || Self.inHeaders(entry.response?.headers, has) {
                return true
            }
            if scopes.contains(.requestBody), Self.inBody(entry.request.body, has) { return true }
            if scopes.contains(.responseBody), Self.inBody(entry.response?.body, has) { return true }
            if scopes.contains(.error), let failure = entry.failure,
               has(failure.kind.rawValue) || has(failure.message) || has(failure.details) {
                return true
            }
            return false
        }
    }

    func apply(_ entries: [PeekEntry]) -> [PeekEntry] {
        guard !isEmpty else { return entries }
        let matcher = compile()
        return entries.filter(matcher)
    }

    private static func inHeaders(_ headers: PeekHeaders?, _ has: (String?) -> Bool) -> Bool {
        guard let headers else { return false }
        return headers.entries.contains { has($0.name) || has($0.value) }
    }

    private static func inBody(_ body: PeekBody?, _ has: (String?) -> Bool) -> Bool {
        switch body {
        case .text(let text, _, _)?:
            has(text)
        case .form(let fields, let files, _)?:
            fields.contains { has($0.name) || has($0.value) } || files.contains { has($0.name) || has($0.filename) }
        default:
            false
        }
    }
}
