import Foundation

nonisolated struct PeekFormField: Hashable, Sendable {
    let name: String
    let value: String

    init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}

nonisolated struct PeekFormFile: Hashable, Sendable {
    let name: String
    let filename: String?
    let contentType: PeekMediaType?
    let size: Int?

    init(_ name: String, filename: String? = nil, contentType: PeekMediaType? = nil, size: Int? = nil) {
        self.name = name
        self.filename = filename
        self.contentType = contentType
        self.size = size
    }
}
