import Foundation

nonisolated enum PeekFailureKind: String, CaseIterable, Sendable {
    case timeout
    case connection
    case badCertificate
    case cancelled
    case badResponse
    case unknown
}

/// `details` and `stackTrace` arrive as text: the codec writes them with `toString()`.
nonisolated struct PeekFailure: Hashable, Sendable {
    let kind: PeekFailureKind
    let message: String
    let details: String?
    let stackTrace: String?

    init(kind: PeekFailureKind, message: String, details: String? = nil, stackTrace: String? = nil) {
        self.kind = kind
        self.message = message
        self.details = details
        self.stackTrace = stackTrace
    }
}
