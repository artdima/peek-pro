import Foundation
import Testing
@testable import Peek_Pro

@Suite("File writer")
struct PeekFileWriterTests {
    /// `basic.peek` as Peek Pro writes it back: identical, except `extra` values the model keeps as text.
    private func expectedBasicLines() throws -> [String] {
        try Spec.lines("basic.peek").map { $0.replacingOccurrences(of: #""extra":{"retry":2,"#, with: #""extra":{"retry":"2","#) }
    }

    private func written(_ name: String) throws -> [String] {
        let contents = try PeekFileReader.read(try Spec.url(name))
        let data = PeekFileWriter.data(info: contents.header.info, entries: contents.entries)
        return String(decoding: data, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    @Test("writes basic.peek back line for line, as Peek wrote it")
    func basic() throws {
        let lines = try written("basic.peek")
        let expected = try expectedBasicLines()
        #expect(lines.last == "")
        #expect(Array(lines.dropLast()).count == expected.count)
        for (line, original) in zip(lines, expected) {
            #expect(line == original)
        }
    }

    @Test("drops what it doesn't know, so unknown-keys.peek comes out as basic.peek")
    func unknownKeys() throws {
        #expect(Array(try written("unknown-keys.peek").dropLast()) == (try expectedBasicLines()))
    }

    @Test("reads back what it wrote, for every readable reference file")
    func roundTrip() throws {
        for (name, expectation) in try Spec.manifest() where !expectation.isRefused {
            let original = try PeekFileReader.read(try Spec.url(name))
            let data = PeekFileWriter.data(info: original.header.info, entries: original.entries)
            let reread = try PeekFileReader.read(data)
            #expect(reread.header.info == original.header.info, "\(name)")
            #expect(reread.header.formatVersion == PeekFileWriter.formatVersion, "\(name)")
            #expect(reread.entries == original.entries, "\(name)")
            #expect(reread.skippedLines == 0, "\(name)")
        }
    }

    @Test("saves a body still on the device as unavailable, keeping its type and size")
    func remoteBody() throws {
        let start = QueryFixtures.start
        let entry = PeekEntry(
            id: PeekId("r"),
            request: PeekRequest(method: "GET", uri: URL(string: "https://api.example.com/config")!),
            startedAt: start,
            source: "dio",
            response: PeekResponse(statusCode: 200, body: .remote(size: 2_048, contentType: .json)),
            completedAt: start.addingTimeInterval(0.1),
            isPinned: true
        )
        let line = PeekFileWriter.entryLine(entry)
        #expect(line.contains(#""pinned":true"#))
        #expect(line.contains(#""body":{"kind":"unavailable","reason":"notCaptured","size":2048,"type":"application/json"}"#))
        let reread = try PeekFileReader.read(PeekFileWriter.data(info: info, entries: [entry])).entries.first
        #expect(reread?.response?.body == .unavailable(.notCaptured, contentType: .json, size: 2_048))
        #expect(reread?.isPinned == true)
    }

    @Test("leaves optional header keys out when there's nothing to say")
    func header() {
        let bare = PeekSessionInfo(name: nil, platform: .android, osVersion: nil, peekVersion: "2.0.0", startedAt: QueryFixtures.start)
        #expect(PeekFileWriter.headerLine(bare)
            == #"{"format":"peek","formatVersion":1,"peekVersion":"2.0.0","platform":"android","startedAt":"2026-09-10T12:00:00.000Z"}"#)
    }

    @Test("writes an empty session as its header alone")
    func emptySession() throws {
        let data = PeekFileWriter.data(info: info, entries: [])
        #expect(String(decoding: data, as: UTF8.self) == PeekFileWriter.headerLine(info) + "\n")
        #expect(try PeekFileReader.read(data).entries.isEmpty)
    }

    private var info: PeekSessionInfo {
        PeekSessionInfo(name: "Shop", platform: .iOS, osVersion: "26.0", peekVersion: "2.0.0", startedAt: QueryFixtures.start)
    }
}
