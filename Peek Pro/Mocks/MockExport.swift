import Foundation

/// Rough stand-ins for the text and Markdown exporters of Phase 4, so the copy actions put something real on the pasteboard.
enum MockExport {
    static func text(_ entry: PeekEntry) -> String {
        var lines = [
            "\(entry.request.method) \(entry.request.uri.absoluteString)",
            "\(entry.statusTitle) · \(entry.duration.map { PeekFormat.duration($0) } ?? "pending")",
            "",
            "Request headers:",
        ]
        lines += entry.request.headers.entries.map { "  \($0.name): \($0.value)" }
        if let response = entry.response {
            lines += ["", "Response headers:"]
            lines += response.headers.entries.map { "  \($0.name): \($0.value)" }
        }
        return lines.joined(separator: "\n")
    }

    static func markdown(_ entry: PeekEntry) -> String {
        """
        ### `\(entry.request.method) \(entry.request.uri.absoluteString)`

        - **Status:** \(entry.statusTitle)
        - **Duration:** \(entry.duration.map { PeekFormat.duration($0) } ?? "pending")
        - **Started:** \(PeekFormat.dateTime(entry.startedAt))
        - **Source:** \(entry.source)
        """
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
