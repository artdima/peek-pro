import Foundation

enum SettingsKey {
    static let port = "server.port"
    static let tokenPolicy = "server.tokenPolicy"
    static let bonjourEnabled = "server.bonjourEnabled"
    static let bonjourName = "server.bonjourName"
    static let bodyFontSize = "body.fontSize"
    static let jsonMode = "body.jsonMode"
    static let wraps = "body.wraps"

    static let defaultPort = 9741
}

enum TokenPolicy: String, CaseIterable, Identifiable {
    case perLaunch
    case persistent

    var id: Self { self }

    var title: String {
        switch self {
        case .perLaunch: "New token at every launch"
        case .persistent: "Keep the same token"
        }
    }
}
