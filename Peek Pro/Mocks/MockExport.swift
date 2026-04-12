import Foundation

/// Rough stand-ins for the exporters of Phase 4, so the copy actions put something real on the pasteboard.
enum MockExport {
    static func curl(_ entry: PeekEntry, multiline: Bool = true) -> String {
        let request = entry.request
        var parts = ["curl" + (request.method == "GET" ? "" : " -X \(request.method)") + " \(quote(request.uri.absoluteString))"]
        let isMultipart = request.body.contentType?.isMultipart == true
        for header in request.headers.entries {
            if isMultipart, header.name.lowercased() == "content-type" { continue }
            parts.append("-H \(quote("\(header.name): \(header.value)"))")
        }
        switch request.body {
        case .text(let text, let type, _):
            if type?.isFormUrlEncoded == true {
                for field in FormURLEncoding.fields(in: text) {
                    parts.append("--data-urlencode \(quote("\(field.name)=\(field.value)"))")
                }
            } else {
                parts.append("--data-raw \(quote(text))")
            }
        case .form(let fields, let files, _):
            for field in fields {
                parts.append("--form-string \(quote("\(field.name)=\(field.value)"))")
            }
            for file in files {
                parts.append("-F \(quote("\(file.name)=@\(file.filename ?? file.name)"))")
            }
        default:
            break
        }
        return parts.joined(separator: multiline ? " \\\n  " : " ")
    }

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
