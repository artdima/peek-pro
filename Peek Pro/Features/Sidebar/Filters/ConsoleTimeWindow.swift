import Foundation

/// Counts back from the latest request rather than from now, so a file from last week still filters sensibly.
nonisolated enum ConsoleTimeWindow: Int, CaseIterable, Identifiable, Sendable {
    case any = 0
    case last5 = 5
    case last15 = 15
    case last60 = 60

    var id: Self { self }

    var title: String {
        switch self {
        case .any: "Any Time"
        case .last5: "Last 5 Minutes"
        case .last15: "Last 15 Minutes"
        case .last60: "Last Hour"
        }
    }

    func dates(latest: Date?) -> PeekDateRange {
        guard self != .any, let latest else { return .any }
        return PeekDateRange(from: latest.addingTimeInterval(-Double(rawValue) * 60))
    }
}

nonisolated extension Set {
    /// Lets a checkbox bind straight to membership: `$filter.methods[contains: "GET"]`.
    subscript(contains element: Element) -> Bool {
        get { contains(element) }
        set {
            if newValue { insert(element) } else { remove(element) }
        }
    }
}
