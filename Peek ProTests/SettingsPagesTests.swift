import Testing
@testable import Peek_Pro

@Suite("Settings pages")
struct SettingsPagesTests {
    @Test("every page sits under one heading, and the headings keep the sidebar's order")
    func groups() {
        let listed = SettingsGroup.allCases.flatMap(\.pages)
        #expect(listed == SettingsPage.allCases)
        #expect(SettingsGroup.allCases.allSatisfy { !$0.pages.isEmpty })
        #expect(SettingsGroup.app.pages == [.general, .appearance])
        #expect(SettingsGroup.connection.pages == [.server, .pairing, .devices])
        #expect(SettingsGroup.peekPro.pages == [.help])
    }

    @Test("search finds a page by its title or by what it holds, whatever the case")
    func search() {
        #expect(SettingsPage.matching("") == SettingsPage.allCases)
        #expect(SettingsPage.matching("   ") == SettingsPage.allCases)
        #expect(SettingsPage.matching("port") == [.server])
        #expect(SettingsPage.matching("FONT") == [.appearance])
        #expect(SettingsPage.matching("token") == [.pairing])
        #expect(SettingsPage.matching("GitHub") == [.help])
        #expect(SettingsPage.matching("pair") == [.pairing, .devices])
        #expect(SettingsPage.matching("nothing like this").isEmpty)
    }

    @Test("a stored page opens again; nothing or nonsense opens the first page")
    func stored() {
        #expect(SettingsPage.stored("devices") == .devices)
        #expect(SettingsPage.stored(nil) == .general)
        #expect(SettingsPage.stored("tabs") == .general)
    }

    @Test("the history goes back and forward, and a new page forgets what was ahead")
    func history() {
        var history = SettingsHistory(start: .general)
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)

        history.visit(.server)
        history.visit(.pairing)
        #expect(history.current == .pairing)
        #expect(history.canGoBack)

        history.goBack()
        #expect(history.current == .server)
        #expect(history.canGoForward)
        history.goBack()
        #expect(history.current == .general)
        #expect(!history.canGoBack)
        history.goBack()
        #expect(history.current == .general)

        history.goForward()
        #expect(history.current == .server)
        history.visit(.help)
        #expect(history.current == .help)
        #expect(!history.canGoForward)
        #expect(history.pages == [.general, .server, .help])
    }

    @Test("landing on the current page again is not a step")
    func noRepeat() {
        var history = SettingsHistory(start: .general)
        history.visit(.general)
        #expect(history.pages == [.general])
        history.visit(.devices)
        history.visit(.devices)
        #expect(history.pages == [.general, .devices])
    }
}
