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

/// How a captured body is best shown.
private enum BodyKind {
    case json(String)
    case formEncoded(String)
    case text(String)
    case image(Data)
    case binary(Data)
    case form([PeekFormField], [PeekFormFile])

    init?(_ payload: PeekBody) {
        switch payload {
        case .form(let fields, let files, _):
            self = .form(fields, files)
            return
        case .bytes(let data, let type, _) where type?.isImage == true:
            self = .image(data)
            return
        default:
            break
        }
        if let text = payload.displayText {
            if payload.looksLikeJSON {
                self = .json(text)
            } else if payload.contentType?.isFormUrlEncoded == true {
                self = .formEncoded(text)
            } else {
                self = .text(text)
            }
        } else if case .bytes(let data, _, _) = payload {
            self = .binary(data)
        } else {
            return nil
        }
    }
}

/// A body with its header bar: type and size, the view switch, wrap, find, copy and save.
struct BodyViewer: View {
    let payload: PeekBody
    let baseName: String
    var loadKey: PeekBodyLoadKey?

    @AppStorage(SettingsKey.jsonMode) private var jsonMode: JSONViewMode = .raw
    @AppStorage(SettingsKey.bodyFontSize) private var fontSize = 12.0
    @AppStorage("body.formMode") private var formMode: FormViewMode = .fields
    @AppStorage(SettingsKey.wraps) private var wraps = false
    @State private var proxy = CodeTextProxy()

    var body: some View {
        switch payload {
        case .unavailable(let reason, let type, let size):
            UnavailableBodyView(reason: reason, contentType: type, size: size)
        case .remote(let size, let type, _):
            RemoteBodyView(size: size, contentType: type, loadKey: loadKey)
        default:
            if payload.isEmpty {
                ContentUnavailableView("No Body", systemImage: "doc",
                                       description: Text("This message was sent without a body."))
            } else if let kind = BodyKind(payload) {
                VStack(spacing: 0) {
                    header(kind)
                    Divider()
                    ForEach(notices(kind), id: \.self) { notice in
                        TruncationBanner(text: notice)
                        Divider()
                    }
                    content(kind)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func showsCode(_ kind: BodyKind) -> Bool {
        switch kind {
        case .json: jsonMode == .raw
        case .formEncoded: formMode == .raw
        case .text, .binary: true
        case .image, .form: false
        }
    }

    private func canWrap(_ kind: BodyKind) -> Bool {
        if case .binary = kind { return false }
        return true
    }

    private func header(_ kind: BodyKind) -> some View {
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
            switch kind {
            case .json:
                Picker("Format", selection: $jsonMode) {
                    ForEach(JSONViewMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            case .formEncoded:
                Picker("Format", selection: $formMode) {
                    ForEach(FormViewMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            default:
                EmptyView()
            }
            if showsCode(kind) {
                if canWrap(kind) {
                    Toggle("Wrap Lines", isOn: $wraps)
                        .toggleStyle(.checkbox)
                }
                Button {
                    proxy.showFind()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .help("Find in body (⌘F)")
            }
            if let text = payload.displayText {
                CopyButton(text: text, title: "Copy Body")
            } else if let data = payload.rawData {
                CopyButton(text: data.base64EncodedString(), title: "Copy as Base64")
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
    private func content(_ kind: BodyKind) -> some View {
        switch kind {
        case .json(let text):
            if jsonMode == .tree {
                JSONTreeView(text: text)
            } else {
                CodeTextView(text: text, syntax: .json, wraps: wraps, fontSize: fontSize, proxy: proxy)
            }
        case .formEncoded(let text):
            if formMode == .fields {
                FormBodyView(fields: FormURLEncoding.fields(in: text))
            } else {
                CodeTextView(text: text, wraps: wraps, fontSize: fontSize, proxy: proxy)
            }
        case .text(let text):
            CodeTextView(text: text, wraps: wraps, fontSize: fontSize, proxy: proxy)
        case .binary(let data):
            CodeTextView(text: HexDump.format(data), wraps: false, fontSize: fontSize, proxy: proxy)
        case .image(let data):
            ImageBodyView(data: data)
        case .form(let fields, let files):
            FormBodyView(fields: fields.map { (name: $0.name, value: $0.value) }, files: files)
        }
    }

    private func notices(_ kind: BodyKind) -> [String] {
        var result: [String] = []
        if payload.isTruncated, let size = payload.size, let captured = payload.capturedSize {
            result.append("Showing the first \(PeekFormat.bytes(captured)) of \(PeekFormat.bytes(size)) — Peek keeps only the start of large bodies.")
        }
        if case .binary(let data) = kind, data.count > HexDump.limit {
            result.append("The hex view shows the first \(PeekFormat.bytes(HexDump.limit)); save the body to see all of it.")
        }
        return result
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
