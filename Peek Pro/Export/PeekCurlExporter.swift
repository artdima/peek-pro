import Foundation

/// Mirrors `PeekCurlExporter` from Peek core: a request as a `curl` command to paste into a shell.
///
/// Values are single-quoted for POSIX shells. Masked values stay masked — the device never sent the
/// originals. Bodies that can't be reproduced — bytes, streams — become a trailing comment instead of a broken command.
nonisolated struct PeekCurlExporter: Sendable {
    /// Puts every header and data option on its own continued line after `curl -X METHOD 'url'`.
    var multiline = true

    func export(_ entry: PeekEntry) -> String {
        exportRequest(entry.request)
    }

    func exportRequest(_ request: PeekRequest) -> String {
        let body = request.body
        var head = ["curl"]
        var options: [String] = []
        var notes: [String] = []

        let sendsData = switch body {
        case .text, .form, .bytes: true
        case .empty, .unavailable, .remote: false
        }
        // -X HEAD leaves curl waiting for a body no server will send.
        if request.method == "HEAD" {
            head.append("-I")
        } else if request.method != "GET" || sendsData {
            head.append("-X \(request.method)")
        }
        head.append(Self.quote(request.uri.absoluteString))

        let isMultipart = if case .form(_, let files, let type) = body { !files.isEmpty || type?.isMultipart == true } else { false }
        for header in request.headers.entries {
            let name = header.name.lowercased()
            if name == "content-length" { continue }
            if isMultipart, name == "content-type" { continue }
            options.append("-H \(Self.quote("\(header.name): \(header.value)"))")
        }

        switch body {
        case .text(let text, _, _):
            options.append("--data-raw \(Self.quote(text))")
            if body.isTruncated {
                notes.append("body truncated: \(body.capturedSize ?? 0) of \(body.size ?? 0) bytes")
            }
        case .form(let fields, let files, _) where isMultipart:
            for field in fields {
                options.append("--form-string \(Self.quote("\(field.name)=\(field.value)"))")
            }
            for file in files {
                let path = file.filename ?? file.name
                let spec = file.contentType.map { "\(file.name)=@\(path);type=\($0)" } ?? "\(file.name)=@\(path)"
                options.append("-F \(Self.quote(spec))")
            }
            if !files.isEmpty {
                notes.append("file contents are not captured; point @ at real files")
            }
        case .form(let fields, _, _):
            for field in fields {
                options.append("--data-urlencode \(Self.quote("\(field.name)=\(field.value)"))")
            }
        case .bytes(_, let type, _):
            options.append("--data-binary '@body.bin'")
            notes.append("body.bin: \(body.size ?? 0) bytes\(type.map { " of \($0)" } ?? ""), not exported")
        case .unavailable(let reason, _, _):
            notes.append("body not captured (\(reason.rawValue))")
        case .remote:
            // Peek Pro only: the body can still be fetched, which Peek's exporter never has to say.
            notes.append("body still on the device; load it to include it")
        case .empty:
            break
        }

        let separator = multiline ? " \\\n  " : " "
        let command = ([head.joined(separator: " ")] + options).joined(separator: separator)
        guard !notes.isEmpty else { return command }
        let comments = notes.map { "# \($0)" }.joined(separator: "\n")
        return multiline ? "\(command)\n\(comments)" : "\(command) \(comments)"
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// Mirrors `PeekExporters`: every way Peek Pro hands an entry to something else.
nonisolated enum PeekExporters {
    static let curl = PeekCurlExporter()
    static let text = PeekTextExporter()
    static let markdown = PeekMarkdownExporter()
    static let har = PeekHarExporter()

    static func url(_ entry: PeekEntry) -> String {
        entry.request.uri.absoluteString
    }
}
