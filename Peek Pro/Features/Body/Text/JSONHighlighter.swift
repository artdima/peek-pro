import Foundation

nonisolated struct CodeToken: Sendable {
    nonisolated enum Kind: Sendable {
        case string
        case number
        case keyword
    }

    let kind: Kind
    let range: NSRange
}

/// A forgiving scan for colors only: it never fails, so a truncated or broken body still gets highlighted.
nonisolated enum JSONHighlighter {
    private static let trueWord = Array("true".utf16)
    private static let falseWord = Array("false".utf16)
    private static let nullWord = Array("null".utf16)

    static func tokens(in text: String) -> [CodeToken] {
        let units = Array(text.utf16)
        let count = units.count
        var tokens: [CodeToken] = []
        var index = 0
        while index < count {
            let unit = units[index]
            if unit == 0x22 {
                let start = index
                index = endOfString(units, from: index + 1)
                if !isFollowedByColon(units, from: index) {
                    tokens.append(CodeToken(kind: .string, range: NSRange(location: start, length: index - start)))
                }
            } else if unit == 0x2D || (unit >= 0x30 && unit <= 0x39) {
                let start = index
                index += 1
                while index < count, isNumberPart(units[index]) { index += 1 }
                tokens.append(CodeToken(kind: .number, range: NSRange(location: start, length: index - start)))
            } else if unit >= 0x61 && unit <= 0x7A {
                let start = index
                while index < count, units[index] >= 0x61 && units[index] <= 0x7A { index += 1 }
                let word = units[start..<index]
                if word.elementsEqual(trueWord) || word.elementsEqual(falseWord) || word.elementsEqual(nullWord) {
                    tokens.append(CodeToken(kind: .keyword, range: NSRange(location: start, length: index - start)))
                }
            } else {
                index += 1
            }
        }
        return tokens
    }

    private static func endOfString(_ units: [UInt16], from start: Int) -> Int {
        var index = start
        while index < units.count {
            let unit = units[index]
            if unit == 0x5C {
                index += 2
                continue
            }
            if unit == 0x22 { return index + 1 }
            if unit == 0x0A { return index }
            index += 1
        }
        return min(index, units.count)
    }

    private static func isFollowedByColon(_ units: [UInt16], from start: Int) -> Bool {
        var index = start
        while index < units.count, units[index] == 0x20 || units[index] == 0x09 { index += 1 }
        return index < units.count && units[index] == 0x3A
    }

    private static func isNumberPart(_ unit: UInt16) -> Bool {
        (unit >= 0x30 && unit <= 0x39) || unit == 0x2E || unit == 0x65 || unit == 0x45 || unit == 0x2B || unit == 0x2D
    }
}
