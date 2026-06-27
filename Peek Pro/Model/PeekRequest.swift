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

    var contentLength: Int? { headers.contentLength ?? body.size }
    var mediaType: PeekMediaType? { body.contentType ?? PeekMediaType(parsing: headers.contentType) }
}
