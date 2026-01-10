import Foundation

nonisolated enum PeekStatusClass: String, CaseIterable, Sendable {
    case informational
    case success
    case redirect
    case clientError
    case serverError
    case unknown

    init(statusCode: Int) {
        switch statusCode {
        case 100..<200: self = .informational
        case 200..<300: self = .success
        case 300..<400: self = .redirect
        case 400..<500: self = .clientError
        case 500..<600: self = .serverError
        default: self = .unknown
        }
    }

    var isError: Bool { self == .clientError || self == .serverError }
}
