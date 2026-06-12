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
        #expect(loaded.entries.count == 17)
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

@Suite("Open Recent")
struct RecentFilesTests {
    private func recent(_ path: String) -> RecentFile {
        RecentFile(url: URL(filePath: path), bookmark: Data(path.utf8))
    }

    @Test("puts the newest first and lists a file once")
    func order() {
        var files = RecentFiles()
        files.add(recent("/tmp/a.peek"))
        files.add(recent("/tmp/b.peek"))
        files.add(recent("/tmp/./a.peek"))
        #expect(files.items.map(\.name) == ["a.peek", "b.peek"])
    }

    @Test("keeps at most ten")
    func limit() {
        var files = RecentFiles()
        for index in 0..<15 { files.add(recent("/tmp/\(index).peek")) }
        #expect(files.items.count == RecentFiles.limit)
        #expect(files.items.first?.name == "14.peek")
        #expect(files.items.last?.name == "5.peek")
    }

    @Test("removes and clears")
    func removal() {
        var files = RecentFiles([recent("/tmp/a.peek"), recent("/tmp/b.peek")])
        files.remove(URL(filePath: "/tmp/a.peek"))
        #expect(files.items.map(\.name) == ["b.peek"])
        files.clear()
        #expect(files.items.isEmpty)
    }

    @Test("drops bookmarks that no longer resolve")
    func unresolvable() throws {
        let defaults = try #require(UserDefaults(suiteName: "RecentFilesTests"))
        defer { defaults.removePersistentDomain(forName: "RecentFilesTests") }
        RecentFiles([recent("/tmp/gone.peek")]).save(to: defaults)
        #expect(RecentFiles(defaults: defaults).items.isEmpty)
    }
}
