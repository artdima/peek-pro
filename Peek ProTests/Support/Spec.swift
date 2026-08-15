import Foundation

/// The reference files of Peek's `doc/spec/`, copied into `Spec/` by `scripts/sync-peek-spec.sh`.
///
/// Xcode flattens the folder into the test bundle, so every file there needs a name of its own.
enum Spec {
    /// What reading a reference file must give, as `manifest.json` says.
    struct Expectation: Decodable, Equatable {
        var formatVersion: Int?
        var newerFormat: Bool?
        var entries: [String]?
        var skipped: Int?
        var error: Bool?

        var isRefused: Bool { error == true }
    }

    enum Failure: Error, CustomStringConvertible {
        case missing(String)

        var description: String {
            switch self {
            case .missing(let name):
                "\(name) is not in the test bundle; run scripts/sync-peek-spec.sh"
            }
        }
    }

    private final class BundleToken {}

    static var bundle: Bundle { Bundle(for: BundleToken.self) }

    static func url(_ name: String) throws -> URL {
        let file = name as NSString
        guard let url = bundle.url(
            forResource: file.deletingPathExtension,
            withExtension: file.pathExtension.isEmpty ? nil : file.pathExtension
        ) else { throw Failure.missing(name) }
        return url
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }

    /// The Peek commit the files were copied from.
    static func commit() throws -> String {
        String(decoding: try data("PEEK_SPEC_COMMIT"), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The non-blank lines of a reference file, the header first.
    static func lines(_ name: String) throws -> [String] {
        String(decoding: try data(name), as: UTF8.self)
            .split(separator: "\n")
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : String($0) }
            .filter { !$0.allSatisfy(\.isWhitespace) }
    }

    /// The entries of a reference file, header left out, each line decoded on its own.
    static func entryLines(_ name: String) throws -> [String] {
        Array(try lines(name).dropFirst())
    }

    /// Every reference session file by name, with what reading it must give.
    static func manifest() throws -> [String: Expectation] {
        try JSONDecoder().decode([String: Expectation].self, from: data("manifest.json"))
    }

    /// What `remote-manifest.json` says of a reference frame.
    struct FrameExpectation: Decodable, Equatable {
        var type: String
        var direction: String?
        var ignored: Bool?
        var sameAs: String?
    }

    /// Every reference frame by its name in Peek (`hello.json`), with what reading it must give.
    static func frames() throws -> [String: FrameExpectation] {
        try JSONDecoder().decode([String: FrameExpectation].self, from: data("remote-manifest.json"))
    }

    /// The one line of a reference frame, by its name in Peek; the sync script prefixes it with `remote-`.
    static func frameText(_ name: String) throws -> String {
        String(decoding: try data("remote-\(name)"), as: UTF8.self).trimmingCharacters(in: .newlines)
    }
}
