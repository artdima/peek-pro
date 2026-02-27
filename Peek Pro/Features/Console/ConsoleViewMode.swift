import Foundation

enum ConsoleViewMode: String, CaseIterable, Identifiable {
    case table
    case list

    static let storageKey = "consoleViewMode"

    var id: Self { self }

    var title: String {
        switch self {
        case .table: "Table"
        case .list: "List"
        }
    }

    var symbol: String {
        switch self {
        case .table: "tablecells"
        case .list: "list.bullet.rectangle"
        }
    }
}
