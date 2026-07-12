import Foundation

/// A problem in the session; repeats of the same problem on the same endpoint fold into one issue.
nonisolated struct SessionIssue: Identifiable, Hashable, Sendable {
    nonisolated enum Severity: Int, Comparable, Sendable {
        case error
        case warning

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static let slowThreshold = Duration.seconds(3)

    let id: String
    let severity: Severity
    let title: String
    let subtitle: String
    /// Oldest first; empty for issues about the session itself.
    var entryIDs: [PeekId]
    var lastSeen: Date?

    var count: Int { entryIDs.count }
    var latestEntryID: PeekId? { entryIDs.last }

    /// Counted over the whole session, whatever the filters show. Errors first, then the most recent.
    static func issues(in entries: [PeekEntry], droppedCount: Int = 0) -> [SessionIssue] {
        var order: [String] = []
        var byID: [String: SessionIssue] = [:]
        for entry in PeekSort.oldestFirst.apply(entries) {
            guard let issue = issue(for: entry) else { continue }
            if var existing = byID[issue.id] {
                existing.entryIDs.append(entry.id)
                existing.lastSeen = entry.startedAt
                byID[issue.id] = existing
            } else {
                order.append(issue.id)
                byID[issue.id] = issue
            }
        }
        var result = order.compactMap { byID[$0] }
        if droppedCount > 0 {
            result.append(SessionIssue(
                id: "dropped",
                severity: .warning,
                title: "The device dropped \(droppedCount) \(droppedCount == 1 ? "entry" : "entries")",
                subtitle: "Its send queue overflowed while Peek Pro was busy.",
                entryIDs: [],
                lastSeen: nil
            ))
        }
        return result.stableSorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity < rhs.severity ? .orderedAscending : .orderedDescending }
            let left = lhs.lastSeen ?? .distantFuture
            let right = rhs.lastSeen ?? .distantFuture
            return left == right ? .orderedSame : left > right ? .orderedAscending : .orderedDescending
        }
    }

    private static func issue(for entry: PeekEntry) -> SessionIssue? {
        let request = entry.request
        let endpoint = "\(request.method) \(request.host)\(request.path)"
        let make = { (key: String, severity: Severity, title: String) in
            SessionIssue(
                id: "\(key) \(endpoint)",
                severity: severity,
                title: title,
                subtitle: endpoint,
                entryIDs: [entry.id],
                lastSeen: entry.startedAt
            )
        }
        if entry.failure?.kind == .cancelled { return nil }
        // The code first: Dio reports every 4xx/5xx as a badResponse failure, and those fold with plain 4xx/5xx.
        if let code = entry.statusCode, entry.statusClass?.isError == true {
            let title = [String(code), PeekHTTPStatus.reasonPhrase(for: code)].compactMap(\.self).joined(separator: " ")
            return make("status-\(code)", .error, title)
        }
        if let failure = entry.failure {
            return make("failure-\(failure.kind.rawValue)", .error, failure.kind.title)
        }
        if entry.isSlow {
            return make("slow", .warning, "Slow response")
        }
        return nil
    }
}

extension PeekEntry {
    nonisolated var isSlow: Bool {
        guard let duration else { return false }
        return duration >= SessionIssue.slowThreshold
    }
}
