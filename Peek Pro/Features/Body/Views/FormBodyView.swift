import SwiftUI

enum FormViewMode: String, CaseIterable, Identifiable {
    case fields
    case raw

    var id: Self { self }

    var title: String {
        switch self {
        case .fields: "Fields"
        case .raw: "Raw"
        }
    }
}

nonisolated enum FormURLEncoding {
    static func fields(in text: String) -> [(name: String, value: String)] {
        text.split(separator: "&", omittingEmptySubsequences: true).map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = decode(parts.first.map(String.init) ?? "")
            let value = parts.count > 1 ? decode(String(parts[1])) : ""
            return (name: name, value: value)
        }
    }

    private static func decode(_ text: String) -> String {
        let spaced = text.replacingOccurrences(of: "+", with: " ")
        return spaced.removingPercentEncoding ?? spaced
    }
}

/// Multipart and URL-encoded forms: fields as name / value, files by what the device knew about them.
struct FormBodyView: View {
    let fields: [(name: String, value: String)]
    var files: [PeekFormFile] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                KeyValueSection(title: "Fields", pairs: KeyValuePair.list(fields), emptyText: "No fields")
                if !files.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Files")
                                .font(.headline)
                            Text(files.count, format: .number)
                                .foregroundStyle(.tertiary)
                        }
                        ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                            FormFileRow(file: file)
                        }
                        Text("Peek records what a file was, not its contents.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FormFileRow: View {
    let file: PeekFormFile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: file.contentType?.isImage == true ? "photo" : "doc")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename ?? "Unnamed file")
                    .fontWeight(.medium)
                Text(details)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private var details: String {
        [
            "field \(file.name)",
            file.contentType?.mimeType,
            file.size.map { PeekFormat.bytes($0) },
        ].compactMap(\.self).joined(separator: " · ")
    }
}

#Preview("Multipart") {
    FormBodyView(
        fields: [(name: "title", value: "September receipt"), (name: "folder", value: "expenses")],
        files: [
            PeekFormFile("file", filename: "receipt-2026-09.pdf", contentType: PeekMediaType("application", "pdf"), size: 482_113),
            PeekFormFile("thumbnail", filename: "receipt.jpg", contentType: PeekMediaType("image", "jpeg"), size: 24_310),
        ]
    )
    .frame(width: 700, height: 420)
}

#Preview("URL-encoded — Dark") {
    FormBodyView(fields: FormURLEncoding.fields(in: FixtureBodies.tokenRequest))
        .frame(width: 700, height: 300)
        .preferredColorScheme(.dark)
}
