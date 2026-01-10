import Foundation

nonisolated enum PeekBodyUnavailableReason: String, CaseIterable, Sendable {
    case streamed
    case tooLarge
    case notCaptured
    case unreadable
}

/// `size` is the size of the original body; a captured prefix shorter than it means truncation.
nonisolated enum PeekBody: Hashable, Sendable {
    case empty
    case text(String, contentType: PeekMediaType? = nil, size: Int? = nil)
    case bytes(Data, contentType: PeekMediaType? = nil, size: Int? = nil)
    case form(fields: [PeekFormField] = [], files: [PeekFormFile] = [], contentType: PeekMediaType? = nil)
    case unavailable(PeekBodyUnavailableReason, contentType: PeekMediaType? = nil, size: Int? = nil)
    /// The body stays on the device and is loaded on request.
    case remote(size: Int, contentType: PeekMediaType? = nil, isTruncated: Bool = false)

    static func json(_ text: String, size: Int? = nil) -> PeekBody {
        .text(text, contentType: .json, size: size)
    }

    var contentType: PeekMediaType? {
        switch self {
        case .empty: nil
        case .text(_, let type, _), .bytes(_, let type, _), .unavailable(_, let type, _): type
        case .form(_, _, let type): type
        case .remote(_, let type, _): type
        }
    }

    var size: Int? {
        switch self {
        case .empty: 0
        case .text(let text, _, let size): max(size ?? 0, text.utf8.count)
        case .bytes(let data, _, let size): max(size ?? 0, data.count)
        case .form: nil
        case .unavailable(_, _, let size): size
        case .remote(let size, _, _): size
        }
    }

    var capturedSize: Int? {
        switch self {
        case .text(let text, _, _): text.utf8.count
        case .bytes(let data, _, _): data.count
        default: nil
        }
    }

    var isTruncated: Bool {
        switch self {
        case .text, .bytes: (size ?? 0) > (capturedSize ?? 0)
        case .remote(_, _, let isTruncated): isTruncated
        default: false
        }
    }

    var isEmpty: Bool {
        switch self {
        case .empty: true
        case .text(let text, _, _): text.isEmpty
        case .bytes(let data, _, _): data.isEmpty
        case .form(let fields, let files, _): fields.isEmpty && files.isEmpty
        case .unavailable, .remote: false
        }
    }
}
