import Foundation

/// Mirrors `PeekMarkdownExporter` from Peek core: an entry as Markdown, for an issue or a pull request.
/// Bodies go in fenced blocks tagged with the language the media type suggests, so JSON arrives highlighted.
nonisolated struct PeekMarkdownExporter: Sendable {
    /// How much of a body is written before it is cut short.
    var maxBodyChars = 4_000

    func export(_ entry: PeekEntry) -> String {
        let request = entry.request
        var lines = ["### \(request.method) \(request.uri.absoluteString)", ""]
        lines += summary(entry)
        lines += ["", "#### Request"]
        lines += headers(request.headers)
        lines += body(request.body, mediaType: request.mediaType)

        if let response = entry.response {
            lines += ["", "#### Response"]
            lines += headers(response.headers)
            lines += body(response.body, mediaType: response.mediaType)
        }

        if let failure = entry.failure {
            lines += ["", "#### Error", "", "**\(failure.kind.rawValue)** — \(failure.message)"]
            if let details = failure.details {
                lines += ["", "```", details, "```"]
            }
        }
        return lines.joined(separator: "\n")
    }

    private func summary(_ entry: PeekEntry) -> [String] {
        let message = entry.response?.statusMessage
        var rows: [(String, String)] = []
        switch entry.state {
        case .pending:
            rows.append(("Outcome", "Pending"))
        case .completed:
            rows.append(("Outcome", "`\(entry.statusCode.map(String.init) ?? "")`\(message.map { " \($0)" } ?? "")"))
        case .failed:
            rows.append(("Outcome", "Failed — `\(entry.failure?.kind.rawValue ?? "unknown")`"))
        }
        if let duration = entry.duration { rows.append(("Duration", PeekExportFormat.duration(duration))) }
        if let size = entry.requestSize, size > 0 { rows.append(("Request", PeekExportFormat.bytes(size))) }
        if let size = entry.responseSize, size > 0 { rows.append(("Response", PeekExportFormat.bytes(size))) }
        rows.append(("Started", PeekExportFormat.timestamp(entry.startedAt)))
        rows.append(("Source", "`\(entry.source)`"))
        return ["| Field | Value |", "| --- | --- |"] + rows.map { "| \($0.0) | \($0.1) |" }
    }

    private func headers(_ headers: PeekHeaders) -> [String] {
        guard !headers.isEmpty else { return ["", "_No headers._"] }
        return ["", "| Header | Value |", "| --- | --- |"]
            + headers.entries.map { "| `\($0.name)` | \(Self.escape($0.value)) |" }
    }

    private func body(_ body: PeekBody, mediaType: PeekMediaType?) -> [String] {
        guard let text = PeekTextExporter.describe(body, maxChars: maxBodyChars) else { return [] }
        return ["", "```\(Self.language(body, mediaType))", text, "```"]
    }

    private static func language(_ body: PeekBody, _ mediaType: PeekMediaType?) -> String {
        guard case .text = body, let mediaType else { return "" }
        if mediaType.isJson { return "json" }
        if mediaType.isXml { return "xml" }
        if mediaType.isHtml { return "html" }
        return ""
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "|", with: "\\|")
    }
}
