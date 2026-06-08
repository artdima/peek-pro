import Foundation

/// The first line of a `.peek` file.
nonisolated struct PeekFileHeader: Hashable, Sendable {
    let formatVersion: Int
    let info: PeekSessionInfo

    var isNewerFormat: Bool { formatVersion > PeekSessionFile.supportedFormatVersion }
}

nonisolated struct PeekFileContents: Sendable {
    let header: PeekFileHeader
    /// In the order their ids first appear; a later line for the same id replaces the entry in place.
    let entries: [PeekEntry]
    let skippedLines: Int
}

nonisolated enum PeekFileError: Error, Equatable {
    /// No header line at all.
    case empty
    /// The first line is not a Peek session header.
    case notASession
    /// The header says so, but the format predates what this build reads. `info` is whatever of the
    /// header could still be read.
    case unsupportedFormat(version: Int, info: PeekSessionInfo?)
}

/// Reads `.peek` files as `Spec/session-format.md` describes them, a line at a time.
nonisolated enum PeekFileReader {
    static let oldestReadableFormatVersion = 1

    static func read(_ url: URL, chunkSize: Int = 64 * 1024) throws -> PeekFileContents {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try read { try handle.read(upToCount: chunkSize) }
    }

    static func read(_ data: Data, chunkSize: Int = 64 * 1024) throws -> PeekFileContents {
        var offset = data.startIndex
        return try read {
            guard offset < data.endIndex else { return nil }
            let end = data.index(offset, offsetBy: chunkSize, limitedBy: data.endIndex) ?? data.endIndex
            defer { offset = end }
            return data[offset..<end]
        }
    }

    private static func read(nextChunk: () throws -> Data?) throws -> PeekFileContents {
        let decoder = JSONDecoder()
        var header: PeekFileHeader?
        var entries: [PeekEntry] = []
        var positions: [PeekId: Int] = [:]
        var skipped = 0

        func take(_ line: Data) throws {
            var line = line
            if header == nil, line.starts(with: byteOrderMark) { line = line.dropFirst(byteOrderMark.count) }
            line = trimmed(line)
            guard !line.isEmpty else { return }
            guard header != nil else {
                header = try readHeader(line, decoder: decoder)
                return
            }
            guard let entry = try? decoder.decode(PeekEntry.self, from: line) else {
                skipped += 1
                return
            }
            if let position = positions[entry.id] {
                entries[position] = entry
            } else {
                positions[entry.id] = entries.count
                entries.append(entry)
            }
        }

        var pending = Data()
        while let chunk = try nextChunk(), !chunk.isEmpty {
            pending.append(chunk)
            var lineStart = pending.startIndex
            while let newline = pending[lineStart...].firstIndex(of: 0x0A) {
                try take(pending[lineStart..<newline])
                lineStart = pending.index(after: newline)
            }
            pending = Data(pending[lineStart...])
        }
        // A file cut off mid-write loses only its last line: it is read if whole, skipped if not.
        try take(pending)

        guard let header else { throw PeekFileError.empty }
        return PeekFileContents(header: header, entries: entries, skippedLines: skipped)
    }

    private static let byteOrderMark = Data([0xEF, 0xBB, 0xBF])

    private static let blank: Set<UInt8> = [0x20, 0x09, 0x0D]

    /// Drops surrounding spaces, tabs and the `\r` a Windows line ending leaves behind.
    private static func trimmed(_ line: Data) -> Data {
        guard let first = line.firstIndex(where: { !blank.contains($0) }),
              let last = line.lastIndex(where: { !blank.contains($0) })
        else { return Data() }
        return line[first...last]
    }

    private static func readHeader(_ line: Data, decoder: JSONDecoder) throws -> PeekFileHeader {
        guard let marker = try? decoder.decode(HeaderMarker.self, from: line), marker.format == "peek" else {
            throw PeekFileError.notASession
        }
        guard let version = marker.formatVersion else { throw PeekFileError.notASession }
        let info = try? decoder.decode(HeaderInfo.self, from: line).info
        guard version >= oldestReadableFormatVersion else {
            throw PeekFileError.unsupportedFormat(version: version, info: info)
        }
        guard let info else { throw PeekFileError.notASession }
        return PeekFileHeader(formatVersion: version, info: info)
    }

    private nonisolated struct HeaderMarker: Decodable {
        let format: String?
        let formatVersion: Int?

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            format = try? container.decodeIfPresent(String.self, forKey: .format)
            formatVersion = try? container.decodeIfPresent(Int.self, forKey: .formatVersion)
        }

        private enum CodingKeys: String, CodingKey {
            case format, formatVersion
        }
    }

    private nonisolated struct HeaderInfo: Decodable {
        let info: PeekSessionInfo

        private enum CodingKeys: String, CodingKey {
            case peekVersion, name, platform, osVersion, startedAt
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let startedAtText = try container.decode(String.self, forKey: .startedAt)
            guard let startedAt = PeekTimestamp.parse(startedAtText) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .startedAt, in: container, debugDescription: "Not an ISO 8601 time: \(startedAtText)"
                )
            }
            info = PeekSessionInfo(
                name: try container.decodeIfPresent(String.self, forKey: .name),
                platform: PeekPlatform(rawValue: try container.decode(String.self, forKey: .platform)),
                osVersion: try container.decodeIfPresent(String.self, forKey: .osVersion),
                peekVersion: try container.decode(String.self, forKey: .peekVersion),
                startedAt: startedAt
            )
        }
    }
}
