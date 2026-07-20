import Foundation

/// What to color in a `CodeTextView`.
nonisolated enum CodeSyntax: Equatable, Sendable {
    case plain
    case json
    case curl

    func tokens(in text: String) -> [CodeToken] {
        switch self {
        case .plain: []
        case .json: JSONHighlighter.tokens(in: text)
        case .curl: CurlHighlighter.tokens(in: text)
        }
    }
}

/// Colors the `curl` word, `-X` / `--data` style flags, single-quoted arguments and `# notes`.
nonisolated enum CurlHighlighter {
    private static let curlWord = Array("curl".utf16)

    static func tokens(in text: String) -> [CodeToken] {
        let units = Array(text.utf16)
        var result: [CodeToken] = []
        var index = 0
        var atWordStart = true
        while index < units.count {
            let unit = units[index]
            if unit == 0x27 {
                let start = index
                index += 1
                while index < units.count, units[index] != 0x27 { index += 1 }
                index = min(index + 1, units.count)
                result.append(CodeToken(kind: .string, range: NSRange(location: start, length: index - start)))
                atWordStart = false
            } else if atWordStart, unit == 0x23 {
                let start = index
                while index < units.count, units[index] != 0x0A { index += 1 }
                result.append(CodeToken(kind: .comment, range: NSRange(location: start, length: index - start)))
            } else if atWordStart, unit == 0x2D {
                let start = index
                while index < units.count, units[index] != 0x20, units[index] != 0x0A { index += 1 }
                result.append(CodeToken(kind: .number, range: NSRange(location: start, length: index - start)))
                atWordStart = false
            } else if atWordStart, index + curlWord.count <= units.count,
                      units[index..<index + curlWord.count].elementsEqual(curlWord) {
                result.append(CodeToken(kind: .keyword, range: NSRange(location: index, length: curlWord.count)))
                index += curlWord.count
                atWordStart = false
            } else {
                atWordStart = unit == 0x20 || unit == 0x0A
                index += 1
            }
        }
        return result
    }
}
