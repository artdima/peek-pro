import SwiftUI

/// The pages of Settings, in the sidebar's order.
nonisolated enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case appearance
    case server
    case pairing
    case devices
    case help

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .server: "Server"
        case .pairing: "Pairing"
        case .devices: "Devices"
        case .help: "Help"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "paintbrush.fill"
        case .server: "antenna.radiowaves.left.and.right"
        case .pairing: "key.fill"
        case .devices: "iphone"
        case .help: "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .appearance: .purple
        case .server: .blue
        case .pairing: .orange
        case .devices: .green
        case .help: .gray
        }
    }

    var group: SettingsGroup {
        switch self {
        case .general, .appearance: .app
        case .server, .pairing, .devices: .connection
        case .help: .peekPro
        }
    }

    /// What the search field finds the page by, besides its title.
    var keywords: [String] {
        switch self {
        case .general: ["requests", "table", "list", "details", "layout"]
        case .appearance: ["font", "size", "json", "tree", "raw", "wrap", "bodies"]
        case .server: ["port", "address", "listening", "bonjour", "network", "advertise"]
        case .pairing: ["code", "token", "access", "ci", "regenerate"]
        case .devices: ["paired", "forget", "iphone", "android", "simulator"]
        case .help: ["guide", "github", "issue", "version", "links", "connecting"]
        }
    }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        if needle.isEmpty { return true }
        return title.lowercased().contains(needle) || keywords.contains { $0.contains(needle) }
    }

    /// The pages matching [query], in the sidebar's order.
    static func matching(_ query: String) -> [SettingsPage] {
        allCases.filter { $0.matches(query) }
    }

    /// What a stored value opens; the first page when nothing or nonsense is stored.
    static func stored(_ rawValue: String?) -> SettingsPage {
        rawValue.flatMap(SettingsPage.init(rawValue:)) ?? .general
    }
}

/// The headings the sidebar groups the pages under.
nonisolated enum SettingsGroup: CaseIterable, Identifiable {
    case app
    case connection
    case peekPro

    var id: Self { self }

    var title: String {
        switch self {
        case .app: "App"
        case .connection: "Connection"
        case .peekPro: "Peek Pro"
        }
    }

    var pages: [SettingsPage] {
        SettingsPage.allCases.filter { $0.group == self }
    }
}

/// Where the person has been in Settings, for the back and forward buttons.
nonisolated struct SettingsHistory: Equatable {
    private(set) var pages: [SettingsPage]
    private(set) var index: Int

    init(start: SettingsPage) {
        pages = [start]
        index = 0
    }

    var current: SettingsPage { pages[index] }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < pages.count - 1 }

    /// Records a page opened from the sidebar; what was ahead is forgotten.
    mutating func visit(_ page: SettingsPage) {
        guard page != current else { return }
        pages.removeSubrange((index + 1)...)
        pages.append(page)
        index += 1
    }

    mutating func goBack() {
        if canGoBack { index -= 1 }
    }

    mutating func goForward() {
        if canGoForward { index += 1 }
    }
}
