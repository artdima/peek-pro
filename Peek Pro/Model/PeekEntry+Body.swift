import Foundation

extension PeekEntry {
    func body(on side: PeekBodySide) -> PeekBody? {
        switch side {
        case .request: request.body
        case .response: response?.body
        }
    }

    /// The same call with one body swapped; a response side without a response stays as it is.
    func replacingBody(_ body: PeekBody, on side: PeekBodySide) -> PeekEntry {
        switch side {
        case .response:
            guard let response else { return self }
            var entry = self
            entry.response = PeekResponse(
                statusCode: response.statusCode,
                statusMessage: response.statusMessage,
                headers: response.headers,
                body: body,
                redirects: response.redirects
            )
            return entry
        case .request:
            return PeekEntry(
                id: id,
                request: PeekRequest(method: request.method, uri: request.uri, headers: request.headers, body: body, extra: request.extra),
                startedAt: startedAt,
                source: source,
                response: response,
                failure: failure,
                completedAt: completedAt,
                isPinned: isPinned,
                timings: timings
            )
        }
    }

    var hasRemoteBody: Bool {
        if case .remote = request.body { return true }
        if case .remote? = response?.body { return true }
        return false
    }

    /// The device sends a held-back body as `remote` every time; one already fetched shouldn't turn back into it.
    func keepingLoadedBodies(of held: PeekEntry) -> PeekEntry {
        var entry = self
        for side in [PeekBodySide.request, .response] {
            guard case .remote? = entry.body(on: side), let loaded = held.body(on: side) else { continue }
            if case .remote = loaded { continue }
            entry = entry.replacingBody(loaded, on: side)
        }
        return entry
    }
}
