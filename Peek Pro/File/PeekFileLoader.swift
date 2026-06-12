import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// Declared in Info.plist; Peek defines the format, Peek Pro is the app that opens it.
    nonisolated static let peekSession = UTType(exportedAs: "dev.peek.session")
}

/// A `.peek` file read into what the sidebar and console show.
nonisolated struct PeekLoadedFile: Sendable {
    let file: PeekSessionFile
    let entries: [PeekEntry]
    /// For Open Recent: made while the sandbox still grants access to the file.
    let bookmark: Data?
}

nonisolated enum PeekFileLoader {
    /// Blocks while it reads: call it off the main thread.
    static func load(_ url: URL) throws -> PeekLoadedFile {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }

        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)

        func file(info: PeekSessionInfo, formatVersion: Int, skippedLines: Int, failure: PeekFileFailure? = nil) -> PeekSessionFile {
            PeekSessionFile(
                url: url,
                byteCount: values.fileSize ?? 0,
                modifiedAt: values.contentModificationDate ?? .now,
                info: info,
                formatVersion: formatVersion,
                skippedLines: skippedLines,
                failure: failure
            )
        }

        do {
            let contents = try PeekFileReader.read(url)
            return PeekLoadedFile(
                file: file(
                    info: contents.header.info,
                    formatVersion: contents.header.formatVersion,
                    skippedLines: contents.skippedLines
                ),
                entries: contents.entries,
                bookmark: bookmark
            )
        } catch PeekFileError.unsupportedFormat(let version, let info?) {
            // Shown in the sidebar with "Can't Open", so the user sees which file it was and why.
            return PeekLoadedFile(
                file: file(info: info, formatVersion: version, skippedLines: 0, failure: .unsupportedFormat(version: version)),
                entries: [],
                bookmark: bookmark
            )
        }
    }
}

nonisolated extension PeekFileError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .empty:
            "The file is empty."
        case .notASession:
            "The file isn't a Peek session."
        case .unsupportedFormat(let version, _):
            "The file uses session format v\(version), which this version of Peek Pro can't read."
        }
    }
}
