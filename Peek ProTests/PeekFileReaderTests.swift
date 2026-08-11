import Foundation
import Testing
@testable import Peek_Pro

@Suite("Reading .peek files")
struct PeekFileReaderTests {
    @Test("reads every reference file as the manifest says")
    func manifest() throws {
        for (name, expected) in try Spec.manifest().sorted(by: { $0.key < $1.key }) {
            let url = try Spec.url(name)
            if expected.isRefused {
                #expect(throws: PeekFileError.self, "\(name)") { try PeekFileReader.read(url) }
                continue
            }
            let contents = try PeekFileReader.read(url)
            #expect(contents.header.formatVersion == expected.formatVersion, "\(name)")
            #expect(contents.header.isNewerFormat == expected.newerFormat, "\(name)")
            #expect(contents.entries.map(\.id.value) == expected.entries, "\(name)")
            #expect(contents.skippedLines == expected.skipped, "\(name)")
        }
    }

    @Test("reads the header into the session info")
    func header() throws {
        let header = try PeekFileReader.read(try Spec.url("basic.peek")).header
        #expect(header.info == PeekSessionInfo(
            name: "Peek fixtures",
            platform: .iOS,
            osVersion: "18.0",
            peekVersion: "2.0.0",
            startedAt: Date(timeIntervalSince1970: 1_789_041_600)
        ))
    }

    @Test("reads the same whatever the chunks", arguments: [1, 2, 7, 4096])
    func chunks(_ size: Int) throws {
        let url = try Spec.url("basic.peek")
        let whole = try PeekFileReader.read(url)
        let pieces = try PeekFileReader.read(url, chunkSize: size)
        #expect(pieces.entries == whole.entries)
        #expect(pieces.header == whole.header)
    }

    @Test("keeps the last line of an entry written twice, in the first one's place")
    func appended() throws {
        let entries = try PeekFileReader.read(try Spec.url("appended.peek")).entries
        #expect(entries.first?.state == .completed)
        #expect(entries.first?.response?.body == .text("done", contentType: .plainText))
    }

    @Test("ignores a byte order mark, Windows line endings, blank lines and a missing final newline")
    func lineEndings() throws {
        let text = String(decoding: try Spec.data("basic.peek"), as: UTF8.self)
        // Bytes, not characters: Swift counts "\r\n" as one Character.
        let windows = Data(text.replacingOccurrences(of: "\n", with: "\r\n\r\n").utf8).dropLast(4)
        let data = Data([0xEF, 0xBB, 0xBF]) + windows
        let contents = try PeekFileReader.read(data, chunkSize: 5)
        let expected = try Spec.manifest()["basic.peek"]?.entries
        #expect(contents.entries.map(\.id.value) == expected)
        #expect(contents.skippedLines == 0)
    }

    @Test("skips a last line cut off mid-write")
    func cutOff() throws {
        let whole = try Spec.data("basic.peek")
        let lastLine = try #require(try Spec.entryLines("basic.peek").last)
        let data = whole + Data(lastLine.utf8.prefix(lastLine.utf8.count / 2))
        let contents = try PeekFileReader.read(data)
        #expect(contents.skippedLines == 1)
        #expect(contents.entries.count == (try Spec.manifest()["basic.peek"]?.entries?.count))
    }

    @Test("tells an empty file, a foreign file and an old format apart")
    func refusals() throws {
        #expect(throws: PeekFileError.empty) { try PeekFileReader.read(try Spec.url("empty.peek")) }
        #expect(throws: PeekFileError.empty) { try PeekFileReader.read(Data("\n  \n".utf8)) }
        #expect(throws: PeekFileError.notASession) { try PeekFileReader.read(try Spec.url("not-a-session.peek")) }
        #expect(throws: PeekFileError.notASession) { try PeekFileReader.read(Data("not json\n".utf8)) }
        #expect(throws: PeekFileError.notASession) {
            try PeekFileReader.read(Data(#"{"format":"peek","formatVersion":"1"}"#.utf8))
        }
        #expect(throws: PeekFileError.notASession) {
            try PeekFileReader.read(Data(#"{"format":"peek","formatVersion":1,"peekVersion":"2.0.0"}"#.utf8))
        }
        do {
            _ = try PeekFileReader.read(try Spec.url("old-version.peek"))
            Issue.record("an old format must be refused")
        } catch PeekFileError.unsupportedFormat(let version, let info) {
            #expect(version == 0)
            #expect(info?.name == "Peek fixtures")
        }
    }

    @Test("keeps a platform it does not know")
    func unknownPlatform() throws {
        let line = #"{"format":"peek","formatVersion":1,"peekVersion":"3.0.0","platform":"visionos","startedAt":"2026-09-10T12:00:00Z"}"#
        let header = try PeekFileReader.read(Data(line.utf8)).header
        #expect(header.info.platform == .other("visionos"))
        #expect(header.info.name == nil)
        #expect(header.info.osVersion == nil)
    }
}
