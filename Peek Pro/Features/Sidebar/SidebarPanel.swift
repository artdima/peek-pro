import SwiftUI

enum SidebarPanel: String, CaseIterable, Identifiable {
    case sessions
    case filters
    case issues
    case insights
    case info

    var id: Self { self }

    var title: String {
        switch self {
        case .sessions: "Sessions"
        case .filters: "Filters"
        case .issues: "Issues"
        case .insights: "Insights"
        case .info: "Info"
        }
    }

    var symbol: String {
        switch self {
        case .sessions: "folder"
        case .filters: "line.3.horizontal.decrease.circle"
        case .issues: "exclamationmark.triangle"
        case .insights: "chart.pie"
        case .info: "info.circle"
        }
    }

    /// ⌘1…⌘5, as the navigators in Xcode.
    var shortcut: KeyEquivalent {
        KeyEquivalent(Character(String((Self.allCases.firstIndex(of: self) ?? 0) + 1)))
    }
}
