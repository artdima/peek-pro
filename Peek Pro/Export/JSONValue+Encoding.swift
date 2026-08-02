import Foundation

/// Writes JSON the way Dart's `jsonEncode` does, keeping key order — exports then read the same from either app.
nonisolated extension JSONValue {
    static func int(_ value: Int) -> JSONValue { .number(String(value)) }

    /// Dart prints a whole double with `.0`, so `250.0` stays `250.0`.
    static func double(_ value: Double) -> JSONValue {
        if value.isFinite, value == value.rounded(), abs(value) < 1e15 {
            return .number("\(Int64(value)).0")
        }
        return .number("\(value)")
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let members) = self else { return nil }
        return members.first { $0.key == key }?.value
    }

    var items: [JSONValue] {
        if case .array(let items) = self { return items }
        return []
    }

    var keys: [String] {
        if case .object(let members) = self { return members.map(\.key) }
        return []
    }

    /// Compact, or indented by two spaces like `JsonEncoder.withIndent('  ')`.
    func encoded(pretty: Bool = false) -> String {
        var output = ""
        write(to: &output, pretty: pretty, indent: "")
        return output
    }

    private func write(to output: inout String, pretty: Bool, indent: String) {
        switch self {
        case .null: output += "null"
        case .bool(let value): output += value ? "true" : "false"
        case .number(let value): output += value
        case .string(let value): Self.writeString(value, to: &output)
        case .array(let items):
            guard !items.isEmpty else { output += "[]"; return }
            let inner = indent + "  "
            output += "["
            for (index, item) in items.enumerated() {
                if index > 0 { output += "," }
                if pretty { output += "\n" + inner }
                item.write(to: &output, pretty: pretty, indent: inner)
            }
            if pretty { output += "\n" + indent }
            output += "]"
        case .object(let members):
            guard !members.isEmpty else { output += "{}"; return }
            let inner = indent + "  "
            output += "{"
            for (index, member) in members.enumerated() {
                if index > 0 { output += "," }
                if pretty { output += "\n" + inner }
                Self.writeString(member.key, to: &output)
                output += pretty ? ": " : ":"
                member.value.write(to: &output, pretty: pretty, indent: inner)
            }
            if pretty { output += "\n" + indent }
            output += "}"
        }
    }

    private static func writeString(_ value: String, to output: inout String) {
        output += "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            case "\u{8}": output += "\\b"
            case "\u{C}": output += "\\f"
            case let control where control.value < 0x20:
                output += String(format: "\\u%04x", control.value)
            default:
                output.unicodeScalars.append(scalar)
            }
        }
        output += "\""
    }
}

/// Builds an object in the order the keys are written, skipping `nil` values like Dart's collection `if`.
nonisolated func jsonObject(_ members: [(String, JSONValue?)]) -> JSONValue {
    .object(members.compactMap { key, value in value.map { JSONMember(key: key, value: $0) } })
}
