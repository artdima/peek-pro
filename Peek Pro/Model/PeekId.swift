import Foundation

nonisolated struct PeekId: Hashable, Sendable, CustomStringConvertible {
    let value: String

    init(_ value: String) {
        precondition(!value.isEmpty, "PeekId is empty")
        self.value = value
    }

    var description: String { value }
}
