import Foundation

/// Aggregates for the Insights panel; plain arithmetic over the session's entries.
nonisolated struct SessionInsights: Sendable {
    nonisolated enum StatusSlice: CaseIterable, Sendable {
        case success
        case redirect
        case clientError
        case serverError
        case failed
        case pending

        var title: String {
            switch self {
            case .success: "2xx"
            case .redirect: "3xx"
            case .clientError: "4xx"
            case .serverError: "5xx"
            case .failed: "Failed"
            case .pending: "Pending"
            }
        }

        /// A 4xx/5xx counts by its code even when the adapter also calls it a failure — Dio reports them all that way.
        init?(_ entry: PeekEntry) {
            if let statusClass = entry.statusClass, entry.failure == nil || statusClass.isError {
                switch statusClass {
                case .success, .informational: self = .success
                case .redirect: self = .redirect
                case .clientError: self = .clientError
                case .serverError: self = .serverError
                case .unknown: return nil
                }
            } else if entry.failure != nil {
                self = .failed
            } else {
                self = .pending
            }
        }
    }

    nonisolated struct Bucket: Identifiable, Sendable {
        let title: String
        /// `nil` for the last, open-ended bucket.
        let upperBound: Duration?
        let count: Int

        var id: String { title }
    }

    nonisolated struct Host: Identifiable, Sendable {
        let name: String
        let count: Int
        let errors: Int

        var id: String { name }
    }

    static let bucketBounds: [(title: String, upperBound: Duration?)] = [
        ("< 100 ms", .milliseconds(100)), ("< 300 ms", .milliseconds(300)), ("< 1 s", .seconds(1)),
        ("< 3 s", .seconds(3)), ("< 10 s", .seconds(10)), ("10 s +", nil),
    ]

    let total: Int
    let finished: Int
    let errors: Int
    let median: Duration?
    let p95: Duration?
    let sentBytes: Int
    let receivedBytes: Int
    let statuses: [(slice: StatusSlice, count: Int)]
    let buckets: [Bucket]
    let slowest: [PeekEntry]
    let hosts: [Host]
    let redirected: [PeekEntry]

    var errorRate: Double { finished == 0 ? 0 : Double(errors) / Double(finished) }

    init(_ entries: [PeekEntry]) {
        total = entries.count
        let done = entries.filter { $0.state != .pending }
        finished = done.count
        errors = done.count(where: \.isError)

        let durations = done.compactMap(\.duration).sorted()
        median = Self.percentile(0.5, of: durations)
        p95 = Self.percentile(0.95, of: durations)

        sentBytes = entries.reduce(0) { $0 + $1.request.headers.byteCount + ($1.requestSize ?? 0) }
        receivedBytes = entries.reduce(0) { total, entry in
            total + (entry.response.map { $0.headers.byteCount + ($0.contentLength ?? 0) } ?? 0)
        }

        var sliceCounts: [StatusSlice: Int] = [:]
        for entry in entries {
            if let slice = StatusSlice(entry) { sliceCounts[slice, default: 0] += 1 }
        }
        statuses = StatusSlice.allCases.compactMap { slice in
            sliceCounts[slice].map { (slice: slice, count: $0) }
        }

        var lower = Duration.zero
        var buckets: [Bucket] = []
        for bound in Self.bucketBounds {
            let count = durations.count(where: { duration in
                duration >= lower && (bound.upperBound.map { duration < $0 } ?? true)
            })
            buckets.append(Bucket(title: bound.title, upperBound: bound.upperBound, count: count))
            lower = bound.upperBound ?? lower
        }
        self.buckets = buckets

        slowest = Array(PeekSort.slowestFirst.apply(done).prefix(5))

        var requestsByHost: [String: Int] = [:]
        var errorsByHost: [String: Int] = [:]
        for entry in entries {
            let host = entry.request.host
            requestsByHost[host, default: 0] += 1
            if entry.isError { errorsByHost[host, default: 0] += 1 }
        }
        var rankedHosts: [Host] = []
        for (name, count) in requestsByHost {
            rankedHosts.append(Host(name: name, count: count, errors: errorsByHost[name] ?? 0))
        }
        rankedHosts.sort(by: Self.isBusier)
        hosts = Array(rankedHosts.prefix(5))

        redirected = entries.filter { !($0.response?.redirects.isEmpty ?? true) }
    }

    private static func isBusier(_ lhs: Host, _ rhs: Host) -> Bool {
        if lhs.count != rhs.count { return lhs.count > rhs.count }
        return lhs.name < rhs.name
    }

    private static func percentile(_ p: Double, of sorted: [Duration]) -> Duration? {
        guard !sorted.isEmpty else { return nil }
        let rank = Int((p * Double(sorted.count)).rounded(.up))
        return sorted[min(max(rank - 1, 0), sorted.count - 1)]
    }
}
