import Foundation

nonisolated enum PeekEntryState: String, CaseIterable, Sendable {
    case pending
    case completed
    case failed
}

nonisolated struct PeekEntry: Identifiable, Hashable, Sendable {
    let id: PeekId
    let request: PeekRequest
    var response: PeekResponse?
    var failure: PeekFailure?
    let startedAt: Date
    var completedAt: Date?
    let source: String
    var isPinned: Bool
    var timings: PeekTimings?

    init(
        id: PeekId,
        request: PeekRequest,
        startedAt: Date,
        source: String,
        response: PeekResponse? = nil,
        failure: PeekFailure? = nil,
        completedAt: Date? = nil,
        isPinned: Bool = false,
        timings: PeekTimings? = nil
    ) {
        self.id = id
        self.request = request
        self.response = response
        self.failure = failure
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.source = source
        self.isPinned = isPinned
        self.timings = timings
    }

    var state: PeekEntryState {
        if failure != nil { return .failed }
        if response != nil { return .completed }
        return .pending
    }

    var duration: Duration? {
        guard let completedAt else { return nil }
        return max(Duration.zero, Duration.seconds(completedAt.timeIntervalSince(startedAt)))
    }

    var isError: Bool { failure != nil || (statusClass?.isError ?? false) }
    var statusCode: Int? { response?.statusCode }
    var statusClass: PeekStatusClass? { response?.statusClass }
    var requestSize: Int? { request.contentLength }
    var responseSize: Int? { response?.contentLength }

    var totalSize: Int? {
        let sizes = [requestSize, responseSize].compactMap(\.self)
        return sizes.isEmpty ? nil : sizes.reduce(0, +)
    }
}
