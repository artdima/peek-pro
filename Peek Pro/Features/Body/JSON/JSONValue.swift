import Foundation

/// Keeps object keys in document order, which `JSONSerialization` loses.
nonisolated indirect enum JSONValue: Sendable {
    case object([JSONMember])
    case array([JSONValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    var isContainer: Bool {
        switch self {
        case .object, .array: true
        default: false
        }
    }

    var childCount: Int {
        switch self {
        case .object(let members): members.count
        case .array(let items): items.count
        default: 0
        }
    }
}

nonisolated struct JSONMember: Sendable {
    let key: String
    let value: JSONValue
}

nonisolated struct JSONParser {
    private struct Failure: Error {}

    private let bytes: [UInt8]
    private var index = 0

    private init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    static func parse(_ text: String) -> JSONValue? {
        var parser = JSONParser(bytes: Array(text.utf8))
        do {
            let value = try parser.parseValue(depth: 0)
            parser.skipWhitespace()
            return parser.index == parser.bytes.count ? value : nil
        } catch {
            return nil
        }
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D: index += 1
            default: return
            }
        }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }

    private mutating func expect(_ byte: UInt8) throws {
        guard consume(byte) else { throw Failure() }
    }

    private mutating func parseValue(depth: Int) throws -> JSONValue {
        guard depth < 512 else { throw Failure() }
        skipWhitespace()
        guard index < bytes.count else { throw Failure() }
        switch bytes[index] {
        case UInt8(ascii: "{"): return try parseObject(depth: depth)
        case UInt8(ascii: "["): return try parseArray(depth: depth)
        case UInt8(ascii: "\""): return .string(try parseString())
        case UInt8(ascii: "t"):
            try parseLiteral("true")
            return .bool(true)
        case UInt8(ascii: "f"):
            try parseLiteral("false")
            return .bool(false)
        case UInt8(ascii: "n"):
            try parseLiteral("null")
            return .null
        default:
            return .number(try parseNumber())
        }
    }

    private mutating func parseObject(depth: Int) throws -> JSONValue {
        index += 1
        var members: [JSONMember] = []
        skipWhitespace()
        if consume(UInt8(ascii: "}")) { return .object(members) }
        while true {
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { throw Failure() }
            let key = try parseString()
            skipWhitespace()
            try expect(UInt8(ascii: ":"))
            let value = try parseValue(depth: depth + 1)
            members.append(JSONMember(key: key, value: value))
            skipWhitespace()
            if consume(UInt8(ascii: ",")) { continue }
            try expect(UInt8(ascii: "}"))
            return .object(members)
        }
    }

    private mutating func parseArray(depth: Int) throws -> JSONValue {
        index += 1
        var items: [JSONValue] = []
        skipWhitespace()
        if consume(UInt8(ascii: "]")) { return .array(items) }
        while true {
            items.append(try parseValue(depth: depth + 1))
            skipWhitespace()
            if consume(UInt8(ascii: ",")) { continue }
            try expect(UInt8(ascii: "]"))
            return .array(items)
        }
    }

    private mutating func parseString() throws -> String {
        index += 1
        var buffer: [UInt8] = []
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            if byte == UInt8(ascii: "\"") {
                return String(decoding: buffer, as: UTF8.self)
            }
            guard byte == UInt8(ascii: "\\") else {
                buffer.append(byte)
                continue
            }
            guard index < bytes.count else { throw Failure() }
            let escaped = bytes[index]
            index += 1
            switch escaped {
            case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"): buffer.append(escaped)
            case UInt8(ascii: "b"): buffer.append(0x08)
            case UInt8(ascii: "f"): buffer.append(0x0C)
            case UInt8(ascii: "n"): buffer.append(0x0A)
            case UInt8(ascii: "r"): buffer.append(0x0D)
            case UInt8(ascii: "t"): buffer.append(0x09)
            case UInt8(ascii: "u"): buffer.append(contentsOf: try parseUnicodeEscape())
            default: throw Failure()
            }
        }
        throw Failure()
    }

    private mutating func parseUnicodeEscape() throws -> [UInt8] {
        var value = UInt32(try parseHex4())
        if value >= 0xD800, value <= 0xDBFF,
           index + 1 < bytes.count, bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u") {
            index += 2
            let low = UInt32(try parseHex4())
            value = (low >= 0xDC00 && low <= 0xDFFF) ? 0x10000 + ((value - 0xD800) << 10) + (low - 0xDC00) : 0xFFFD
        }
        let replacement: Unicode.Scalar = "\u{FFFD}"
        let scalar = Unicode.Scalar(value) ?? replacement
        return Array(String(Character(scalar)).utf8)
    }

    private mutating func parseHex4() throws -> UInt16 {
        guard index + 4 <= bytes.count else { throw Failure() }
        var value: UInt16 = 0
        for _ in 0..<4 {
            let byte = bytes[index]
            index += 1
            let digit: UInt16
            switch byte {
            case 0x30...0x39: digit = UInt16(byte - 0x30)
            case 0x61...0x66: digit = UInt16(byte - 0x61 + 10)
            case 0x41...0x46: digit = UInt16(byte - 0x41 + 10)
            default: throw Failure()
            }
            value = value << 4 | digit
        }
        return value
    }

    private mutating func parseNumber() throws -> String {
        let start = index
        scan: while index < bytes.count {
            switch bytes[index] {
            case 0x30...0x39, UInt8(ascii: "-"), UInt8(ascii: "+"), UInt8(ascii: "."), UInt8(ascii: "e"), UInt8(ascii: "E"):
                index += 1
            default:
                break scan
            }
        }
        guard index > start else { throw Failure() }
        return String(decoding: bytes[start..<index], as: UTF8.self)
    }

    private mutating func parseLiteral(_ word: String) throws {
        let expected = Array(word.utf8)
        guard index + expected.count <= bytes.count,
              bytes[index..<index + expected.count].elementsEqual(expected)
        else { throw Failure() }
        index += expected.count
    }
}

/// One printed line of formatted JSON — what the Tree view shows, folding included.
nonisolated struct JSONLine: Identifiable, Sendable {
    nonisolated enum Kind: Sendable {
        /// `"key": value` or a lone value; empty containers print here as `{}` / `[]`.
        case leaf(JSONValue)
        /// `"key": {` — the start of an expanded container.
        case open(bracket: Character)
        /// `}` — the end of an expanded container.
        case close(bracket: Character)
        /// `"key": { … }` — a folded container.
        case folded(open: Character, close: Character, count: Int)
    }

    let id: String
    /// The node the line belongs to, e.g. `items[3].id`; the root is `$`.
    let path: String
    let depth: Int
    let key: String?
    let kind: Kind
    let hasComma: Bool

    var isFoldable: Bool {
        switch kind {
        case .open, .folded: true
        default: false
        }
    }

    var isExpanded: Bool {
        if case .open = kind { return true }
        return false
    }

    /// Lines that open, close or stand for a container — the ones Expand / Collapse applies to.
    var isContainerLine: Bool {
        if case .leaf = kind { return false }
        return true
    }
}

typealias JSONChild = (key: String?, value: JSONValue, path: String)

nonisolated enum JSONTree {
    static let rootID = "$"
    /// Containers bigger than this start folded, so a huge array doesn't open as tens of thousands of lines.
    static let autoExpandLimit = 50

    static func lines(_ root: JSONValue, expanded: Set<String>) -> [JSONLine] {
        var lines: [JSONLine] = []
        append(root, path: rootID, key: nil, depth: 0, hasComma: false, expanded: expanded, into: &lines)
        return lines
    }

    static func initialExpansion(_ root: JSONValue) -> Set<String> {
        var paths: Set<String> = [rootID]
        collect(root, id: rootID, into: &paths) { $0.childCount <= autoExpandLimit }
        return paths
    }

    static func allContainerPaths(_ root: JSONValue) -> Set<String> {
        var paths: Set<String> = []
        collect(root, id: rootID, into: &paths) { _ in true }
        return paths
    }

    static func value(at path: String, in root: JSONValue) -> JSONValue? {
        if path == rootID { return root }
        var found: JSONValue?
        find(path, in: root, id: rootID, found: &found)
        return found
    }

    static func displayPath(_ id: String) -> String {
        id == rootID ? "" : id
    }

    static func format(_ value: JSONValue, indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        let innerPad = String(repeating: "  ", count: indent + 1)
        switch value {
        case .string(let text):
            return quoted(text)
        case .number(let number):
            return number
        case .bool(let flag):
            return flag ? "true" : "false"
        case .null:
            return "null"
        case .array(let items):
            guard !items.isEmpty else { return "[]" }
            let body = items.map { innerPad + format($0, indent: indent + 1) }.joined(separator: ",\n")
            return "[\n\(body)\n\(pad)]"
        case .object(let members):
            guard !members.isEmpty else { return "{}" }
            let body = members.map { "\(innerPad)\(quoted($0.key)): \(format($0.value, indent: indent + 1))" }
                .joined(separator: ",\n")
            return "{\n\(body)\n\(pad)}"
        }
    }

    static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if scalar.value < 0x20 {
                    result += String(format: "\\u%04x", scalar.value)
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result + "\""
    }

    private static func children(of value: JSONValue, path: String) -> [JSONChild] {
        var result: [JSONChild] = []
        switch value {
        case .object(let members):
            for member in members {
                result.append((key: member.key, value: member.value, path: childPath(path, key: member.key)))
            }
        case .array(let items):
            for (index, item) in items.enumerated() {
                result.append((key: nil, value: item, path: indexPath(path, index: index)))
            }
        default:
            break
        }
        return result
    }

    private static func brackets(of value: JSONValue) -> (open: Character, close: Character)? {
        switch value {
        case .object: ("{", "}")
        case .array: ("[", "]")
        default: nil
        }
    }

    private static func append(
        _ value: JSONValue, path: String, key: String?, depth: Int, hasComma: Bool,
        expanded: Set<String>, into lines: inout [JSONLine]
    ) {
        let items = children(of: value, path: path)
        guard let brackets = brackets(of: value), !items.isEmpty else {
            lines.append(JSONLine(id: path, path: path, depth: depth, key: key, kind: .leaf(value), hasComma: hasComma))
            return
        }
        guard expanded.contains(path) else {
            let kind = JSONLine.Kind.folded(open: brackets.open, close: brackets.close, count: items.count)
            lines.append(JSONLine(id: path, path: path, depth: depth, key: key, kind: kind, hasComma: hasComma))
            return
        }
        lines.append(JSONLine(id: path, path: path, depth: depth, key: key, kind: .open(bracket: brackets.open), hasComma: false))
        for (index, item) in items.enumerated() {
            append(item.value, path: item.path, key: item.key, depth: depth + 1,
                   hasComma: index < items.count - 1, expanded: expanded, into: &lines)
        }
        lines.append(JSONLine(id: path + "#end", path: path, depth: depth, key: nil,
                              kind: .close(bracket: brackets.close), hasComma: hasComma))
    }

    private static func collect(
        _ value: JSONValue, id: String, into paths: inout Set<String>, where include: (JSONValue) -> Bool
    ) {
        guard value.isContainer else { return }
        if include(value) { paths.insert(id) }
        for child in children(of: value, path: id) {
            collect(child.value, id: child.path, into: &paths, where: include)
        }
    }

    private static func find(_ target: String, in value: JSONValue, id: String, found: inout JSONValue?) {
        for child in children(of: value, path: id) where found == nil {
            if child.path == target {
                found = child.value
                return
            }
            if target.hasPrefix(child.path) {
                find(target, in: child.value, id: child.path, found: &found)
            }
        }
    }

    private static func childPath(_ parent: String, key: String) -> String {
        let isPlain = !key.isEmpty && key.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
        let component = isPlain ? key : "[\(quoted(key))]"
        if parent == rootID { return component }
        return isPlain ? "\(parent).\(component)" : parent + component
    }

    private static func indexPath(_ parent: String, index: Int) -> String {
        (parent == rootID ? "" : parent) + "[\(index)]"
    }
}
