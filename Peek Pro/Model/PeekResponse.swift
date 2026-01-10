import Foundation

nonisolated struct PeekResponse: Hashable, Sendable {
    let statusCode: Int
    let statusMessage: String?
    let headers: PeekHeaders
    let body: PeekBody
    let redirects: [PeekRedirect]

    init(
        statusCode: Int,
        statusMessage: String? = nil,
        headers: PeekHeaders = .empty,
        body: PeekBody = .empty,
        redirects: [PeekRedirect] = []
    ) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headers = headers
        self.body = body
        self.redirects = redirects
    }

    var statusClass: PeekStatusClass { PeekStatusClass(statusCode: statusCode) }
    var contentLength: Int? { headers.contentLength ?? body.size }
    var mediaType: PeekMediaType? { body.contentType ?? PeekMediaType(parsing: headers.contentType) }
}

nonisolated struct PeekRedirect: Hashable, Sendable {
    let statusCode: Int
    let method: String
    let location: URL
}
