import AppKit
import SwiftUI

enum JSONViewMode: String, CaseIterable, Identifiable {
    case raw
    case tree

    var id: Self { self }

    var title: String {
        switch self {
        case .raw: "Raw"
        case .tree: "Tree"
        }
    }
}

extension PeekBody {
    /// Text to show as-is: text bodies, and byte bodies whose type says they are text.
    var displayText: String? {
        switch self {
        case .text(let text, _, _):
            text
        case .bytes(let data, let type, _):
            type?.isText == true ? String(decoding: data, as: UTF8.self) : nil
        default:
            nil
        }
    }

    var looksLikeJSON: Bool {
        if contentType?.isJson == true { return true }
        guard let first = displayText?.first(where: { !$0.isWhitespace }) else { return false }
        return first == "{" || first == "["
    }

    var rawData: Data? {
        switch self {
        case .text(let text, _, _): Data(text.utf8)
        case .bytes(let data, _, _): data
        default: nil
        }
    }
}

/// A body with its header bar: type and size, Raw / Tree for JSON, wrap, find, copy and save.
struct BodyViewer: View {
    let payload: PeekBody
    let baseName: String

    @AppStorage("body.jsonMode") private var jsonMode: JSONViewMode = .raw
    @AppStorage("body.wraps") private var wraps = false
    @State private var proxy = CodeTextProxy()

    var body: some View {
        if payload.isEmpty {
            ContentUnavailableView("No Body", systemImage: "doc",
                                   description: Text("This message was sent without a body."))
        } else {
            VStack(spacing: 0) {
                header
                Divider()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var isTree: Bool {
        payload.looksLikeJSON && jsonMode == .tree
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(payload.contentType?.mimeType ?? "No content type")
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
            if let size = sizeText {
                Text(size)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if payload.looksLikeJSON {
                Picker("Format", selection: $jsonMode) {
                    ForEach(JSONViewMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if payload.displayText != nil && !isTree {
                Toggle("Wrap Lines", isOn: $wraps)
                    .toggleStyle(.checkbox)
                Button {
                    proxy.showFind()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .help("Find in body (⌘F)")
            }
            if let text = payload.displayText {
                CopyButton(text: text, title: "Copy Body")
            }
            if let data = payload.rawData {
                Button {
                    save(data)
                } label: {
                    Label("Save…", systemImage: "square.and.arrow.down")
                }
                .help("Save body to a file")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if let text = payload.displayText {
            if isTree {
                JSONTreeView(text: text)
            } else {
                CodeTextView(text: text, highlightsJSON: payload.looksLikeJSON, wraps: wraps, proxy: proxy)
            }
        } else {
            BodyKindPlaceholder(payload: payload)
        }
    }

    private var sizeText: String? {
        guard let size = payload.size else { return nil }
        if payload.isTruncated, let captured = payload.capturedSize {
            return "\(PeekFormat.bytes(captured)) of \(PeekFormat.bytes(size))"
        }
        return PeekFormat.bytes(size)
    }

    private var fileExtension: String {
        guard let type = payload.contentType else { return "txt" }
        if type.isJson { return "json" }
        if type.isHtml { return "html" }
        if type.isXml { return "xml" }
        if type.isImage { return type.subtype == "jpeg" ? "jpg" : type.subtype }
        return type.isText ? "txt" : "bin"
    }

    private func save(_ data: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(baseName).\(fileExtension)"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }
}

/// What the body is, for kinds that get their own viewers next.
private struct BodyKindPlaceholder: View {
    let payload: PeekBody

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
    }

    private var title: String {
        switch payload {
        case .bytes(_, let type, _): type?.isImage == true ? "Image" : "Binary Body"
        case .form: "Form"
        case .unavailable: "Body Not Available"
        case .remote: "Body Is on the Device"
        default: "Body"
        }
    }

    private var symbol: String {
        switch payload {
        case .bytes(_, let type, _): type?.isImage == true ? "photo" : "doc.zipper"
        case .form: "list.bullet.rectangle"
        case .unavailable: "eye.slash"
        case .remote: "iphone.and.arrow.forward"
        default: "doc"
        }
    }

    private var detail: String {
        switch payload {
        case .form(let fields, let files, _):
            "\(fields.count) fields, \(files.count) files"
        case .unavailable(let reason, _, _):
            reason.title
        default:
            payload.size.map { PeekFormat.bytes($0) } ?? ""
        }
    }
}
