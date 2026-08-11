import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Peek_Pro

@Suite("Opening .peek files")
struct PeekFileLoaderTests {
    @Test("declares .peek in the app's Info.plist")
    func documentType() throws {
        let info = try #require(Bundle.main.infoDictionary)
        let exported = try #require((info["UTExportedTypeDeclarations"] as? [[String: Any]])?.first)
        #expect(exported["UTTypeIdentifier"] as? String == UTType.peekSession.identifier)
        let tags = exported["UTTypeTagSpecification"] as? [String: Any]
        #expect(tags?["public.filename-extension"] as? [String] == ["peek"])
        let document = try #require((info["CFBundleDocumentTypes"] as? [[String: Any]])?.first)
        #expect(document["LSItemContentTypes"] as? [String] == ["dev.peek.session"])
        #expect(document["CFBundleTypeRole"] as? String == "Viewer")
    }

    @Test("describes the file as the sidebar shows it")
    func loadsFile() throws {
        let url = try Spec.url("basic.peek")
        let loaded = try PeekFileLoader.load(url)
        #expect(loaded.file.url == url)
        let byteCount = try Spec.data("basic.peek").count
        #expect(loaded.file.byteCount == byteCount)
        #expect(loaded.file.info.name == "Peek fixtures")
        #expect(loaded.file.formatVersion == 1)
        #expect(loaded.file.skippedLines == 0)
        #expect(loaded.file.failure == nil)
        #expect(loaded.entries.count == (try Spec.manifest()["basic.peek"]?.entries?.count))
    }

    @Test("counts skipped lines and flags a newer format")
    func warnings() throws {
        let broken = try PeekFileLoader.load(try Spec.url("broken-line.peek")).file
        #expect(broken.skippedLines == 2)
        #expect(broken.hasWarnings)
        let future = try PeekFileLoader.load(try Spec.url("future-version.peek")).file
        #expect(future.isNewerFormat)
    }

    @Test("keeps an old format in the list, marked as unreadable")
    func oldFormat() throws {
        let loaded = try PeekFileLoader.load(try Spec.url("old-version.peek"))
        #expect(loaded.file.failure == .unsupportedFormat(version: 0))
        #expect(loaded.file.info.name == "Peek fixtures")
        #expect(loaded.entries.isEmpty)
    }

    @Test("refuses a file that is not a session, saying why")
    func refuses() throws {
        #expect(throws: PeekFileError.notASession) { try PeekFileLoader.load(try Spec.url("not-a-session.peek")) }
        #expect(throws: PeekFileError.empty) { try PeekFileLoader.load(try Spec.url("empty.peek")) }
        #expect(PeekFileError.notASession.localizedDescription == "The file isn't a Peek session.")
    }
}

@Suite("File bookmarks")
struct FileBookmarksTests {
    private func bookmark(_ path: String) -> FileBookmark {
        FileBookmark(url: URL(filePath: path), bookmark: Data(path.utf8))
    }

    private func list(_ items: [FileBookmark] = [], limit: Int = 10) -> FileBookmarks {
        FileBookmarks(storageKey: "test", limit: limit, items: items)
    }

    @Test("puts the newest first and lists a file once")
    func order() {
        var files = list()
        files.add(bookmark("/tmp/a.peek"))
        files.add(bookmark("/tmp/b.peek"))
        files.add(bookmark("/tmp/./a.peek"))
        #expect(files.items.map(\.name) == ["a.peek", "b.peek"])
    }

    @Test("keeps at most its limit")
    func limit() {
        var files = list(limit: 10)
        for index in 0..<15 { files.add(bookmark("/tmp/\(index).peek")) }
        #expect(files.items.count == 10)
        #expect(files.items.first?.name == "14.peek")
        #expect(files.items.last?.name == "5.peek")
    }

    @Test("removes, replaces in place and clears")
    func editing() {
        var files = list([bookmark("/tmp/a.peek"), bookmark("/tmp/b.peek"), bookmark("/tmp/c.peek")])
        files.remove(URL(filePath: "/tmp/a.peek"))
        #expect(files.items.map(\.name) == ["b.peek", "c.peek"])
        files.replace(URL(filePath: "/tmp/b.peek"), with: FileBookmark(url: URL(filePath: "/tmp/b.peek"), bookmark: Data("fresh".utf8)))
        #expect(files.items.map(\.name) == ["b.peek", "c.peek"])
        #expect(files.items.first?.bookmark == Data("fresh".utf8))
        files.clear()
        #expect(files.items.isEmpty)
    }

    @Test("keeps recent and open files apart and drops bookmarks that no longer resolve")
    func storage() throws {
        let defaults = try #require(UserDefaults(suiteName: "FileBookmarksTests"))
        defer { defaults.removePersistentDomain(forName: "FileBookmarksTests") }
        #expect(FileBookmarks.recent(defaults).storageKey != FileBookmarks.open(defaults).storageKey)
        #expect(FileBookmarks.recent(defaults).limit == 10)
        list([bookmark("/tmp/gone.peek")]).save(to: defaults)
        #expect(defaults.array(forKey: "test")?.count == 1)
        #expect(FileBookmarks(storageKey: "test", limit: 10, defaults: defaults).items.isEmpty)
    }
}
