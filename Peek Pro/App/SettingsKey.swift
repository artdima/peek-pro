import Foundation

enum SettingsKey {
    static let port = "server.port"
    static let tokenPolicy = "server.tokenPolicy"
    /// Kept only while the policy is `.persistent`.
    static let token = "server.token"
    /// Made once; devices keep their token under it.
    static let serverID = "server.id"
    /// The paired devices, as JSON; their tokens are in the Keychain.
    static let pairedDevices = "server.pairedDevices"
    static let bonjourEnabled = "server.bonjourEnabled"
    static let bonjourName = "server.bonjourName"
    static let bodyFontSize = "body.fontSize"
    static let jsonMode = "body.jsonMode"
    static let wraps = "body.wraps"
    /// The Settings page shown last, and the one a link into Settings asks for.
    static let settingsPage = "settings.page"

    static let defaultPort = 9741
}

enum TokenPolicy: String, CaseIterable, Identifiable {
    case perLaunch
    case persistent

    var id: Self { self }

    static var current: TokenPolicy {
        TokenPolicy(rawValue: UserDefaults.standard.string(forKey: SettingsKey.tokenPolicy) ?? "") ?? .perLaunch
    }

    var title: String {
        switch self {
        case .perLaunch: "New token at every launch"
        case .persistent: "Keep the same token"
        }
    }
}
