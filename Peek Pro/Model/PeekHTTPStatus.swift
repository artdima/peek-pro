import Foundation

nonisolated enum PeekHTTPStatus {
    static func reasonPhrase(for statusCode: Int) -> String? {
        phrases[statusCode]
    }

    private static let phrases: [Int: String] = [
        100: "Continue", 101: "Switching Protocols",
        200: "OK", 201: "Created", 202: "Accepted", 203: "Non-Authoritative Information",
        204: "No Content", 205: "Reset Content", 206: "Partial Content",
        300: "Multiple Choices", 301: "Moved Permanently", 302: "Found", 303: "See Other",
        304: "Not Modified", 307: "Temporary Redirect", 308: "Permanent Redirect",
        400: "Bad Request", 401: "Unauthorized", 402: "Payment Required", 403: "Forbidden",
        404: "Not Found", 405: "Method Not Allowed", 406: "Not Acceptable", 408: "Request Timeout",
        409: "Conflict", 410: "Gone", 411: "Length Required", 412: "Precondition Failed",
        413: "Content Too Large", 414: "URI Too Long", 415: "Unsupported Media Type",
        418: "I'm a Teapot", 422: "Unprocessable Content", 423: "Locked", 425: "Too Early",
        426: "Upgrade Required", 428: "Precondition Required", 429: "Too Many Requests",
        431: "Request Header Fields Too Large", 451: "Unavailable For Legal Reasons",
        500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway",
        503: "Service Unavailable", 504: "Gateway Timeout", 505: "HTTP Version Not Supported",
    ]
}
