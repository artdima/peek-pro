import SwiftUI

nonisolated enum CurlHighlighter {
    nonisolated enum Kind: Sendable {
        case command
        case flag
        case string
    }

    private static let curlWord = Array("curl".utf16)

    /// Colors the `curl` word, `-X` / `--data` style flags and single-quoted arguments.
    static func tokens(in text: String) -> [(kind: Kind, range: NSRange)] {
        let units = Array(text.utf16)
        var result: [(kind: Kind, range: NSRange)] = []
        var index = 0
        var atWordStart = true
        while index < units.count {
            let unit = units[index]
            if unit == 0x27 {
                let start = index
                index += 1
                while index < units.count, units[index] != 0x27 { index += 1 }
                index = min(index + 1, units.count)
                result.append((kind: .string, range: NSRange(location: start, length: index - start)))
                atWordStart = false
            } else if atWordStart, unit == 0x2D {
                let start = index
                while index < units.count, units[index] != 0x20, units[index] != 0x0A { index += 1 }
                result.append((kind: .flag, range: NSRange(location: start, length: index - start)))
                atWordStart = false
            } else if atWordStart, index + curlWord.count <= units.count,
                      units[index..<index + curlWord.count].elementsEqual(curlWord) {
                result.append((kind: .command, range: NSRange(location: index, length: curlWord.count)))
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

struct CurlTab: View {
    let entry: PeekEntry

    @AppStorage("curl.multiline") private var isMultiline = true

    var body: some View {
        let command = MockExport.curl(entry, multiline: isMultiline)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Paste into a terminal to repeat the request.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Multiline", isOn: $isMultiline)
                    .toggleStyle(.checkbox)
                CopyButton(text: command, title: "Copy cURL")
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()
            ForEach(notes, id: \.self) { note in
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(note)
                        .font(.callout)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.04))
                Divider()
            }
            ScrollView([.vertical, .horizontal]) {
                Text(highlighted(command))
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: !isMultiline, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
        }
    }

    private var notes: [String] {
        var result: [String] = []
        switch entry.request.body {
        case .bytes: result.append("The binary body is left out — save it from the Request tab and add --data-binary @file.")
        case .form(_, let files, _) where !files.isEmpty: result.append("Files are sent as @placeholders — Peek doesn't keep their contents.")
        case .unavailable(let reason, _, _): result.append("The body isn't included: \(reason.title.lowercased()).")
        case .remote: result.append("The body stayed on the device; load it on the Request tab to include it.")
        default: break
        }
        if entry.request.headers.entries.contains(where: { $0.value.contains("*****") }) {
            result.append("Redacted values are copied as ***** — replace them before running.")
        }
        return result
    }

    private func highlighted(_ command: String) -> AttributedString {
        var text = AttributedString(command)
        for token in CurlHighlighter.tokens(in: command) {
            guard let range = Range(token.range, in: command),
                  let attributed = Range(range, in: text)
            else { continue }
            switch token.kind {
            case .command: text[attributed].foregroundColor = Color(.codeKeyword)
            case .flag: text[attributed].foregroundColor = Color(.codeNumber)
            case .string: text[attributed].foregroundColor = Color(.codeString)
            }
        }
        return text
    }
}

#Preview("POST JSON") {
    CurlTab(entry: Fixtures.entry("f07"))
        .frame(width: 900, height: 420)
}

#Preview("Multipart — Dark") {
    CurlTab(entry: Fixtures.entry("f19"))
        .frame(width: 900, height: 420)
        .preferredColorScheme(.dark)
}

#Preview("Binary") {
    CurlTab(entry: Fixtures.entry("f10"))
        .frame(width: 900, height: 420)
}
