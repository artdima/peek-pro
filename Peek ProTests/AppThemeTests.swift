import AppKit
import Testing
@testable import Peek_Pro

@Suite("App theme")
@MainActor
struct AppThemeTests {
    @Test("a stored theme comes back; nothing or nonsense follows the system")
    func stored() {
        #expect(AppTheme.stored("light") == .light)
        #expect(AppTheme.stored("dark") == .dark)
        #expect(AppTheme.stored(nil) == .system)
        #expect(AppTheme.stored("sepia") == .system)
    }

    @Test("System leaves the appearance to macOS; Light and Dark pin it")
    func appearance() {
        #expect(AppTheme.system.appearanceName == nil)
        #expect(AppTheme.light.appearanceName == .aqua)
        #expect(AppTheme.dark.appearanceName == .darkAqua)
    }
}
