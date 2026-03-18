import Foundation

enum DetailTab: String, CaseIterable, Identifiable {
    case summary
    case request
    case response
    case headers
    case cookies
    case error
    case curl

    var id: Self { self }

    var title: String {
        switch self {
        case .summary: "Summary"
        case .request: "Request"
        case .response: "Response"
        case .headers: "Headers"
        case .cookies: "Cookies"
        case .error: "Error"
        case .curl: "cURL"
        }
    }

    var symbol: String {
        switch self {
        case .summary: "doc.text.magnifyingglass"
        case .request: "arrow.up.doc"
        case .response: "arrow.down.doc"
        case .headers: "list.bullet.rectangle"
        case .cookies: "birthday.cake"
        case .error: "exclamationmark.octagon"
        case .curl: "terminal"
        }
    }

    /// Tabs with nothing to show are left out rather than shown empty.
    static func available(for entry: PeekEntry) -> [DetailTab] {
        allCases.filter { tab in
            switch tab {
            case .cookies:
                !entry.request.headers.cookies.isEmpty || !(entry.response?.headers.setCookies.isEmpty ?? true)
            case .error:
                entry.failure != nil
            default:
                true
            }
        }
    }
}
