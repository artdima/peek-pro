import Foundation

/// A problem in the session; repeats of the same problem on the same endpoint fold into one issue.
nonisolated struct ConsoleIssue: Identifiable, Sendable {
    nonisolated enum Severity: Int, Comparable, Sendable {
        case error
        case warning

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static let slowThreshold: TimeInterval = 3

    let id: String
    let severity: Severity
    let title: String
    let subtitle: String
    /// Oldest first; empty for issues about the session itself.
    var entryIDs: [PeekId]
    var lastSeen: Date?

    var count: Int { entryIDs.count }
    var latestEntryID: PeekId? { entryIDs.last }

    static func issues(in entries: [PeekEntry], droppedCount: Int = 0) -> [ConsoleIssue] {
        var order: [String] = []
        var byKey: [String: ConsoleIssue] = [:]
        for entry in entries.sorted(by: { $0.startedAt < $1.startedAt }) {
            guard let issue = makeIssue(for: entry) else { continue }
            if var existing = byKey[issue.id] {
                existing.entryIDs.append(entry.id)
                existing.lastSeen = entry.startedAt
                byKey[issue.id] = existing
            } else {
                order.append(issue.id)
                byKey[issue.id] = issue
            }
        }
        var result = order.compactMap { byKey[$0] }
        if droppedCount > 0 {
            result.append(ConsoleIssue(
                id: "dropped",
                severity: .warning,
                title: "The device dropped \(droppedCount) \(droppedCount == 1 ? "entry" : "entries")",
                subtitle: "Its send queue overflowed while Peek Pro was busy.",
                entryIDs: [],
                lastSeen: nil
            ))
        }
        return result.sorted {
            if $0.severity != $1.severity { return $0.severity < $1.severity }
            return ($0.lastSeen ?? .distantFuture) > ($1.lastSeen ?? .distantFuture)
        }
    }

    private static func makeIssue(for entry: PeekEntry) -> ConsoleIssue? {
        let request = entry.request
        let endpoint = "\(request.method) \(request.host)\(request.path)"
        let make = { (key: String, severity: Severity, title: String) in
            ConsoleIssue(
                id: "\(key) \(endpoint)",
                severity: severity,
                title: title,
                subtitle: endpoint,
                entryIDs: [entry.id],
                lastSeen: entry.startedAt
            )
        }
        if let failure = entry.failure {
            if failure.kind == .cancelled { return nil }
            if failure.kind == .badResponse, entry.response != nil {
                return make("status-\(entry.statusCode ?? 0)", .error, entry.statusTitle)
            }
            return make("failure-\(failure.kind.rawValue)", .error, failure.kind.title)
        }
        if entry.statusClass?.isError == true {
            return make("status-\(entry.statusCode ?? 0)", .error, entry.statusTitle)
        }
        if let duration = entry.duration?.timeInterval, duration >= slowThreshold {
            return make("slow", .warning, "Slow response")
        }
        return nil
    }
}
