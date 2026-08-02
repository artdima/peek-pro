import Foundation

nonisolated struct PeekRequest: Hashable, Sendable {
    let method: String
    let uri: URL
    let headers: PeekHeaders
    let body: PeekBody
    let extra: [String: String]

    init(
        method: String,
        uri: URL,
        headers: PeekHeaders = .empty,
        body: PeekBody = .empty,
        extra: [String: String] = [:]
    ) {
        self.method = method.uppercased()
        self.uri = uri
        self.headers = headers
        self.body = body
        self.extra = extra
    }

    /// Lowercase, like `Uri.host` in Dart.
    var host: String { uri.host()?.lowercased() ?? "" }
    var path: String { uri.path() }
    var query: String? { uri.query() }

    var queryItems: [URLQueryItem] {
        URLComponents(url: uri, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    /// Like Dart's `Uri.queryParametersAll`: grouped by name in order of first appearance, `+` read as a space.
    var queryParameters: [(name: String, values: [String])] {
        guard let query = uri.query(percentEncoded: true), !query.isEmpty else { return [] }
        var order: [String] = []
        var values: [String: [String]] = [:]
        for pair in query.split(separator: "&", omittingEmptySubsequences: true) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let decode = { (raw: Substring) in
                let spaced = raw.replacingOccurrences(of: "+", with: " ")
                return spaced.removingPercentEncoding ?? spaced
            }
            let name = decode(parts[0])
            if values[name] == nil { order.append(name) }
            values[name, default: []].append(parts.count > 1 ? decode(parts[1]) : "")
        }
        return order.map { (name: $0, values: values[$0] ?? []) }
    }

    var contentLength: Int? { headers.contentLength ?? body.size }
    var mediaType: PeekMediaType? { body.contentType ?? PeekMediaType(parsing: headers.contentType) }
}
