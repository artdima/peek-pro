import AppKit
import UniformTypeIdentifiers

/// Saving and copying what the console shows, through the exporters.
extension AppModel {
    static let textSeparator = "\n\n" + String(repeating: "-", count: 40) + "\n\n"

    /// Pretty-printed, as browsers save HAR: people open these files to read them.
    func exportHAR(_ entries: [PeekEntry]) {
        save(PeekExporters.har.export(entries, pretty: true), as: .har, name: "\(exportName).har")
    }

    func exportText(_ entries: [PeekEntry]) {
        save(text(of: entries), as: .plainText, name: "\(exportName).txt")
    }

    var canSaveSession: Bool {
        guard let id = selectedSessionID else { return false }
        return store.info(for: id) != nil && !selectedEntries.isEmpty
    }

    /// The whole session, whatever the list shows — a saved session should read like the one it came from.
    func saveSession() {
        guard let id = selectedSessionID, let info = store.info(for: id),
              let url = chooseDestination(for: .peekSession, name: "\(exportName).peek")
        else { return }
        let entries = store.entries(in: id)
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PeekFileWriter.write(info: info, entries: entries, to: url)
                }.value
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    func copyText(_ entries: [PeekEntry]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text(of: entries), forType: .string)
    }

    private func text(of entries: [PeekEntry]) -> String {
        entries.map(PeekExporters.text.export).joined(separator: Self.textSeparator)
    }

    /// "Pixel 8 2026-09-25 08.15" — the session and when, with nothing a file name can't hold.
    private var exportName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        let stamp = formatter.string(from: .now)
        let file = selectedSessionID.flatMap { store.file($0) }
        let title = (file?.url.deletingPathExtension().lastPathComponent ?? windowTitle)
            .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return "\(title) \(stamp)"
    }

    private func chooseDestination(for type: UTType, name: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func save(_ text: String, as type: UTType, name: String) {
        guard let url = chooseDestination(for: type, name: name) else { return }
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

extension UTType {
    nonisolated static let har = UTType(filenameExtension: "har", conformingTo: .json) ?? .json
}
