import Foundation
import Testing

@Suite("Peek spec")
struct SpecFixturesTests {
    @Test("records the Peek commit it was copied from")
    func commit() throws {
        let commit = try Spec.commit()
        #expect(commit.count == 40)
        let isHex = commit.allSatisfy(\.isHexDigit)
        #expect(isHex)
    }

    @Test("has the session format and every file the manifest lists")
    func sessionFiles() throws {
        _ = try Spec.url("session-format.md")
        let manifest = try Spec.manifest()
        #expect(manifest["basic.peek"]?.entries?.isEmpty == false)
        for name in manifest.keys.sorted() {
            _ = try Spec.url(name)
        }
    }

    @Test("says what each kind of file must give")
    func manifestShape() throws {
        let manifest = try Spec.manifest()
        #expect(manifest["empty.peek"]?.isRefused == true)
        #expect(manifest["future-version.peek"]?.newerFormat == true)
        #expect(manifest["header-only.peek"]?.entries == [])
        for (name, expectation) in manifest where !expectation.isRefused {
            #expect(expectation.formatVersion != nil, "\(name)")
            #expect(expectation.skipped != nil, "\(name)")
        }
    }
}
