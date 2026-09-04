import Foundation
import Testing
@testable import Peek_Pro

@Suite("Session store")
struct SessionStoreTests {
    private let start = Date(timeIntervalSince1970: 1_789_041_600)

    private func entry(_ id: String, pending: Bool = false, pinned: Bool = false) -> PeekEntry {
        PeekEntry(
            id: PeekId(id),
            request: PeekRequest(method: "GET", uri: URL(string: "https://api.example.com/\(id)")!),
            startedAt: start,
            source: "dio",
            response: pending ? nil : PeekResponse(statusCode: 200),
            completedAt: pending ? nil : start.addingTimeInterval(0.1),
            isPinned: pinned
        )
    }

    private func ids(_ store: SessionStore) -> [String] {
        store.entries.map(\.id.value)
    }

    @Test("keeps arrival order and replaces an entry in place")
    func order() {
        var store = SessionStore()
        store.upsert(entry("a", pending: true))
        store.upsert(entry("b"))
        store.upsert(entry("a"))
        #expect(ids(store) == ["a", "b"])
        #expect(store.entry(PeekId("a"))?.state == .completed)
        #expect(store.count == 2)
    }

    @Test("evicts the oldest completed, unpinned entry first")
    func evictsCompleted() {
        var store = SessionStore(limit: 3, entries: [entry("pending", pending: true), entry("pinned", pinned: true), entry("done")])
        let evicted = store.upsert(entry("new"))
        #expect(evicted?.id.value == "done")
        #expect(ids(store) == ["pending", "pinned", "new"])
    }

    @Test("then the oldest pending, and a pinned entry only as a last resort")
    func evictionOrder() {
        var store = SessionStore(limit: 2, entries: [entry("pinned", pinned: true), entry("pending", pending: true)])
        let evictedPending = store.upsert(entry("next", pending: true))
        #expect(evictedPending?.id.value == "pending")
        store = SessionStore(limit: 2, entries: [entry("p1", pinned: true), entry("p2", pinned: true)])
        let evictedPinned = store.upsert(entry("p3", pinned: true))
        #expect(evictedPinned?.id.value == "p1")
        #expect(store.count == 2)
    }

    @Test("keeps the index right after removals")
    func removal() {
        var store = SessionStore(entries: ["a", "b", "c", "d"].map { entry($0) })
        let removed = store.remove(PeekId("b"))
        let removedAgain = store.remove(PeekId("b"))
        #expect(removed?.id.value == "b")
        #expect(removedAgain == nil)
        #expect(store.entry(PeekId("d"))?.id.value == "d")
        store.upsert(entry("c", pending: true))
        #expect(ids(store) == ["a", "c", "d"])
        #expect(store.entry(PeekId("c"))?.state == .pending)
    }

    @Test("pins and unpins, skipping unknown ids and entries already there")
    func pins() {
        var store = SessionStore(entries: [entry("a"), entry("b", pinned: true), entry("c")])
        let pinned = store.setPinned([PeekId("a"), PeekId("b"), PeekId("missing")], to: true)
        #expect(pinned == 1)
        #expect(store.entries.map(\.isPinned) == [true, true, false])
        let unpinned = store.setPinned([PeekId("a"), PeekId("c")], to: false)
        #expect(unpinned == 1)
        #expect(store.entries.map(\.isPinned) == [false, true, false])
    }

    @Test("keeps the viewer's pin when the source sends the entry again")
    func pinSurvivesUpdates() {
        var store = SessionStore(entries: [entry("a", pending: true), entry("b", pinned: true)])
        store.setPinned([PeekId("a")], to: true)
        store.setPinned([PeekId("b")], to: false)
        store.upsert(entry("a"))
        store.upsert(entry("b", pinned: true))
        #expect(store.entry(PeekId("a"))?.state == .completed)
        #expect(store.entry(PeekId("a"))?.isPinned == true)
        #expect(store.entry(PeekId("b"))?.isPinned == false)
        store.upsert(entry("new", pinned: true))
        #expect(store.entry(PeekId("new"))?.isPinned == true)
    }

    @Test("updates and clears")
    func editing() {
        var store = SessionStore(entries: [entry("a")])
        let updated = store.update(PeekId("a")) { $0.isPinned = true }
        let updatedMissing = store.update(PeekId("missing")) { $0.isPinned = true }
        #expect(updated)
        #expect(!updatedMissing)
        #expect(store.entry(PeekId("a"))?.isPinned == true)
        store.clear()
        #expect(store.isEmpty)
        #expect(store.entry(PeekId("a")) == nil)
        store.upsert(entry("a"))
        #expect(ids(store) == ["a"])
    }

    @Test("reads a whole .peek file")
    func wholeFile() throws {
        let contents = try PeekFileReader.read(try Spec.url("basic.peek"))
        let store = SessionStore(entries: contents.entries)
        #expect(store.entries == contents.entries)
    }
}

@MainActor
@Suite("Session hub")
struct SessionHubTests {
    private func opened() throws -> PeekLoadedFile {
        try PeekFileLoader.load(try Spec.url("basic.peek"))
    }

    @Test("lists no demo files in a live session")
    func noDemoFiles() {
        let hub = SessionHub()
        _ = MockFeed(hub: hub, scenario: .live, isLive: false)
        #expect(hub.files.isEmpty)
        #expect(!hub.sessions.isEmpty)
    }

    @Test("keeps an opened file across scenario switches, above the demo files")
    func keepsOpenedFiles() throws {
        let hub = SessionHub()
        let feed = MockFeed(hub: hub, scenario: .live, isLive: false)
        let loaded = try opened()
        hub.addFile(loaded.file, entries: loaded.entries)
        feed.select(.waiting)
        #expect(hub.files.map(\.id) == [loaded.file.id])
        #expect(hub.entries(in: loaded.file.id).count == (try Spec.manifest()["basic.peek"]?.entries?.count))
        #expect(hub.sessions.isEmpty)
        feed.select(.file)
        #expect(hub.files.first?.id == loaded.file.id)
        #expect(hub.files.count > 1)
    }

    @Test("replaces a file opened twice, and forgets it once closed")
    func reopenAndClose() throws {
        let hub = SessionHub()
        let feed = MockFeed(hub: hub, scenario: .waiting, isLive: false)
        let loaded = try opened()
        hub.addFile(loaded.file, entries: loaded.entries)
        hub.addFile(loaded.file, entries: Array(loaded.entries.prefix(3)))
        #expect(hub.files.count == 1)
        #expect(hub.entries(in: loaded.file.id).count == 3)
        hub.closeFile(loaded.file.id)
        feed.select(.live)
        #expect(hub.files.isEmpty)
    }

    @Test("drops demo files on a scenario switch")
    func demoFilesAreNotKept() {
        let hub = SessionHub()
        let feed = MockFeed(hub: hub, scenario: .waiting, isLive: false)
        feed.openDemoFiles()
        #expect(!hub.files.isEmpty)
        feed.select(.live)
        #expect(hub.files.isEmpty)
    }

    @Test("pins, clears and pauses through the hub")
    func acting() throws {
        let hub = SessionHub()
        let loaded = try opened()
        hub.addFile(loaded.file, entries: loaded.entries)
        let id = loaded.file.id
        hub.setPinned([PeekId("e1")], to: true, in: id)
        #expect(hub.entry(PeekId("e1"), in: id)?.isPinned == true)
        hub.togglePaused(id)
        #expect(hub.isPaused(id))
        hub.clear(id)
        #expect(hub.entries(in: id).isEmpty)
        #expect(hub.file(id) != nil)
    }

    @Test("forgets a file's pins once it is opened again")
    func filePinsLastUntilClosed() throws {
        let hub = SessionHub()
        let loaded = try opened()
        let id = loaded.file.id
        hub.addFile(loaded.file, entries: loaded.entries)
        hub.setPinned([PeekId("e1")], to: true, in: id)
        hub.closeFile(id)
        hub.addFile(loaded.file, entries: loaded.entries)
        #expect(hub.entry(PeekId("e1"), in: id)?.isPinned == false)
    }

    @Test("says so when a body can't be fetched")
    func bodyWithoutDevice() {
        let hub = SessionHub()
        let key = PeekBodyLoadKey(entryID: PeekId("x"), side: .response)
        hub.loadBody(key, in: .live("nobody"))
        #expect(hub.bodyLoad(key, in: .live("nobody")) == .failed("The device isn't connected."))
    }

    @Test("puts a fetched body into the entry")
    func completesBody() throws {
        let hub = SessionHub()
        let loaded = try opened()
        hub.addFile(loaded.file, entries: loaded.entries)
        let key = PeekBodyLoadKey(entryID: PeekId("e1"), side: .response)
        hub.completeBodyLoad(key, in: loaded.file.id, with: .text("fetched"))
        #expect(hub.entry(PeekId("e1"), in: loaded.file.id)?.response?.body == .text("fetched"))
        #expect(hub.bodyLoad(key, in: loaded.file.id) == nil)
        #expect(hub.entry(PeekId("e1"), in: loaded.file.id)?.response?.statusCode == 200)
    }
}
