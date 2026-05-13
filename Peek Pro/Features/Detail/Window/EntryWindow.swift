import SwiftUI

/// What a detached request window remembers across relaunches; plain strings, so it is `Codable`.
nonisolated struct EntryWindowID: Codable, Hashable, Sendable {
    let session: String
    let entry: String
}

extension PeekSessionID {
    nonisolated var storageKey: String {
        switch self {
        case .live(let key): "live:\(key)"
        case .file(let url): "file:\(url.path(percentEncoded: false))"
        }
    }
}

extension AppModel {
    func windowID(for entryID: PeekId) -> EntryWindowID? {
        selectedSessionID.map { EntryWindowID(session: $0.storageKey, entry: entryID.value) }
    }

    func session(for windowID: EntryWindowID) -> PeekSessionID? {
        store.sessionIDs.first { $0.storageKey == windowID.session }
    }

    func entry(for windowID: EntryWindowID) -> PeekEntry? {
        guard let session = session(for: windowID) else { return nil }
        return store.entries(in: session).first { $0.id.value == windowID.entry }
    }
}

/// Opens each request in its own window; a window already showing a request is brought forward.
struct OpenEntryWindowsAction {
    let model: AppModel
    let openWindow: OpenWindowAction

    static let limit = 10

    func callAsFunction(_ ids: some Collection<PeekId>) {
        for id in ids.prefix(Self.limit) {
            if let windowID = model.windowID(for: id) {
                openWindow(value: windowID)
            }
        }
    }
}

extension View {
    /// Double-click or Return opens the selected requests in windows.
    func opensEntryWindows(model: AppModel, openWindow: OpenWindowAction) -> some View {
        contextMenu(forSelectionType: PeekId.self) { ids in
            EntryContextMenu(ids: ids)
        } primaryAction: { ids in
            OpenEntryWindowsAction(model: model, openWindow: openWindow)(ids)
        }
    }
}

struct EntryWindow: View {
    @Environment(AppModel.self) private var model
    let windowID: EntryWindowID

    var body: some View {
        Group {
            if let entry = model.entry(for: windowID) {
                EntryDetailView(entry: entry, isStandalone: true)
                    .navigationTitle(title(for: entry))
                    .navigationSubtitle(subtitle)
            } else {
                ContentUnavailableView {
                    Label("Request Not Available", systemImage: "questionmark.square.dashed")
                } description: {
                    Text("The session it came from was cleared or closed.")
                }
                .navigationTitle("Request")
            }
        }
        .frame(minWidth: 640, minHeight: 420)
    }

    private func title(for entry: PeekEntry) -> String {
        let path = entry.request.path.isEmpty ? "/" : entry.request.path
        return "\(entry.request.method) \(path) — \(entry.statusTitle)"
    }

    private var subtitle: String {
        guard let session = model.session(for: windowID), let info = model.store.info(for: session) else { return "" }
        if let file = model.store.file(session) { return file.name }
        return model.store.session(session)?.title ?? info.name ?? info.systemTitle
    }
}

#Preview("Login") {
    let model = AppModel.preview(.live)
    EntryWindow(windowID: EntryWindowID(session: FixtureSessions.iPhoneSession.id.storageKey, entry: "f01"))
        .environment(model)
        .frame(width: 1000, height: 700)
}

#Preview("Gone — Dark") {
    EntryWindow(windowID: EntryWindowID(session: "live:nowhere", entry: "f01"))
        .environment(AppModel.preview(.live))
        .frame(width: 700, height: 420)
        .preferredColorScheme(.dark)
}
