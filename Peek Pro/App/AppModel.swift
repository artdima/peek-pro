import Foundation
import Observation

/// State shared by the window and the menus; in Phase 3 `store` becomes the real session store.
@Observable
final class AppModel {
    let store: MockStore
    var panel: SidebarPanel = .sessions
    var selectedSessionID: PeekSessionID?

    init(store: MockStore = MockStore()) {
        self.store = store
        selectedSessionID = store.sessionIDs.first
    }

    func selectScenario(_ scenario: MockScenario) {
        store.select(scenario)
        selectedSessionID = store.sessionIDs.first
    }

    var selectedEntries: [PeekEntry] {
        selectedSessionID.map { store.entries(in: $0) } ?? []
    }

    var windowTitle: String {
        guard let id = selectedSessionID else { return "Peek Pro" }
        if let file = store.file(id) { return file.name }
        return store.info(for: id)?.app.name ?? "Peek Pro"
    }

    var windowSubtitle: String {
        guard let id = selectedSessionID, let info = store.info(for: id) else { return "" }
        if store.file(id) != nil { return "\(info.app.name) · \(info.device.name)" }
        return "\(info.device.name) · \(info.device.systemTitle)"
    }
}
