import Foundation

/// Mirrors `PeekTextExporter` from Peek core: an entry as plain text, for a chat or a ticket.
nonisolated struct PeekTextExporter: Sendable {
    /// How much of a body is written before it is cut short.
    var maxBodyChars = 4_000

    func export(_ entry: PeekEntry) -> String {
        var lines = [
            "\(entry.request.method) \(entry.request.uri.absoluteString)",
            outcome(entry),
            "",
            "--- Request ---",
        ]
        lines += headerLines(entry.request.headers)
        lines += bodyLines(entry.request.body)

        if let response = entry.response {
            lines += ["", "--- Response ---"]
            lines += headerLines(response.headers)
            lines += bodyLines(response.body)
        }

        if let failure = entry.failure {
            lines += ["", "--- Error ---", "\(failure.kind.rawValue): \(failure.message)"]
            if let details = failure.details { lines.append("Details: \(details)") }
            if let stackTrace = failure.stackTrace {
                lines += ["", stackTrace.trimmingTrailingWhitespace]
            }
        }
        return lines.joined(separator: "\n")
    }

    private func outcome(_ entry: PeekEntry) -> String {
        var parts: [String] = []
        switch entry.state {
        case .pending:
            parts.append("Pending")
        case .completed:
            parts.append("\(entry.statusCode.map(String.init) ?? "") \(entry.response?.statusMessage ?? "")"
                .trimmingCharacters(in: .whitespaces))
        case .failed:
            parts.append("Failed: \(entry.failure?.kind.rawValue ?? "unknown")")
        }
        if let duration = entry.duration { parts.append(PeekExportFormat.duration(duration)) }
        if let size = entry.requestSize, size > 0 { parts.append("↑ \(PeekExportFormat.bytes(size))") }
        if let size = entry.responseSize, size > 0 { parts.append("↓ \(PeekExportFormat.bytes(size))") }
        parts.append(PeekExportFormat.timestamp(entry.startedAt))
        parts.append(entry.source)
        return parts.joined(separator: " · ")
    }

    private func headerLines(_ headers: PeekHeaders) -> [String] {
        headers.isEmpty ? ["(no headers)"] : headers.entries.map { "\($0.name): \($0.value)" }
    }

    private func bodyLines(_ body: PeekBody) -> [String] {
        Self.describe(body, maxChars: maxBodyChars).map { ["", $0] } ?? []
    }

    /// A body as text, cut to `maxChars`; `nil` when there is nothing to show. Shared with the Markdown exporter.
    static func describe(_ body: PeekBody, maxChars: Int) -> String? {
        switch body {
        case .empty:
            return nil
        case .text(let text, _, _):
            guard !text.isEmpty else { return nil }
            guard text.count > maxChars else { return text }
            return "\(text.prefix(maxChars))\n… \(text.count - maxChars) more characters"
        case .bytes(_, let type, _):
            return "<\(PeekExportFormat.bytes(body.size ?? 0)) of \(type?.description ?? "binary data")>"
        case .form(let fields, let files, _):
            return (fields.map { "\($0.name): \($0.value)" } + files.map(describe(_:))).joined(separator: "\n")
        case .unavailable(let reason, _, _):
            return "<body not captured: \(reason.rawValue)>"
        case .remote(let size, _, _):
            // Peek Pro only: Peek never exports a body it could still fetch.
            return "<body still on the device: \(PeekExportFormat.bytes(size))>"
        }
    }

    private static func describe(_ file: PeekFormFile) -> String {
        let suffix = file.size.map { ", \(PeekExportFormat.bytes($0))" } ?? ""
        return "\(file.name): <file \(file.filename ?? "")\(suffix)>"
    }
}

nonisolated extension String {
    var trimmingTrailingWhitespace: String {
        var result = self
        while let last = result.last, last.isWhitespace { result.removeLast() }
        return result
    }
}
