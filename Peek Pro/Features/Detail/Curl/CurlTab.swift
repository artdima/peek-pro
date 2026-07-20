import SwiftUI

struct CurlTab: View {
    let entry: PeekEntry

    @AppStorage("curl.multiline") private var isMultiline = true
    @AppStorage(SettingsKey.bodyFontSize) private var fontSize = 12.0

    var body: some View {
        let command = PeekCurlExporter(multiline: isMultiline).export(entry)
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
            CodeTextView(text: command, syntax: .curl, wraps: true, showsLineNumbers: false, fontSize: fontSize)
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
            result.append("Some values were masked on the device and are copied as *****.")
        }
        return result
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
