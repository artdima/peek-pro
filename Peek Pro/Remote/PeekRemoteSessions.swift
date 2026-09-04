import Foundation

/// Speaks the protocol with every device: the handshake, then one live session per app.
final class PeekRemoteSessions {
    nonisolated static let serverName = "Peek Pro"
    nonisolated static let oldestProtocol = PeekRemoteProtocol.version
    nonisolated static let newestProtocol = PeekRemoteProtocol.version

    /// A connection that hasn't said `hello` by then is closed.
    var helloTimeout = Duration.seconds(10)
    /// A body the device hasn't sent by then is given up on; Try Again asks anew.
    var bodyTimeout = Duration.seconds(10)
    /// A session appeared, or came back.
    var onOpen: ((PeekSessionID) -> Void)?

    private let hub: SessionHub
    private let serverVersion: String?
    private var greeting: [ObjectIdentifier: PeekRemoteChannel] = [:]
    private var links: [String: Link] = [:]
    /// Sessions this server opened, connected or not: the ones whose bodies it fetches.
    private var known: Set<String> = []
    private var bodyRequests: [String: BodyRequest] = [:]
    private var lastRequestID = 0

    private struct BodyRequest {
        let session: String
        let key: PeekBodyLoadKey
    }

    private struct Link {
        let channel: PeekRemoteChannel
        /// The history until `synced`, shown in one go rather than call by call.
        var history: SessionStore? = SessionStore()
    }

    init(hub: SessionHub, serverVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) {
        self.hub = hub
        self.serverVersion = serverVersion
    }

    var connectedCount: Int { links.count }

    /// `false` for a session some other source feeds.
    func loadBody(_ key: PeekBodyLoadKey, in id: PeekSessionID) -> Bool {
        guard case .live(let session) = id, known.contains(session) else { return false }
        guard let channel = links[session]?.channel else {
            hub.failBodyLoad(key, in: id, message: "The device is offline. Reconnect it to load the body.")
            return true
        }
        lastRequestID += 1
        let requestID = String(lastRequestID)
        bodyRequests[requestID] = BodyRequest(session: session, key: key)
        channel.send(PeekRemoteFrame.bodyRequest(requestID: requestID, entryID: key.entryID, side: key.side).text)

        let timeout = bodyTimeout
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard let self, self.bodyRequests.removeValue(forKey: requestID) != nil else { return }
            self.hub.failBodyLoad(key, in: id, message: "The device didn't answer within \(timeout.seconds) seconds.")
        }
        return true
    }

    func accept(_ channel: PeekRemoteChannel) {
        let id = ObjectIdentifier(channel)
        greeting[id] = channel
        channel.onText = { [weak self, weak channel] text in
            guard let self, let channel else { return }
            self.greet(channel, text)
        }
        channel.onClose = { [weak self] in self?.greeting[id] = nil }

        let timeout = helloTimeout
        Task { [weak self, weak channel] in
            try? await Task.sleep(for: timeout)
            guard let self, let channel, self.greeting[id] === channel else { return }
            self.greeting[id] = nil
            channel.close()
        }
    }

    /// Everything before `hello` is ignored, and so is what can't be read.
    private func greet(_ channel: PeekRemoteChannel, _ text: String) {
        guard case .hello(let hello)? = try? PeekRemoteFrame(text: text) else { return }
        greeting[ObjectIdentifier(channel)] = nil

        let check = PeekRemoteProtocol.check(
            hello,
            token: hub.server.token,
            oldest: Self.oldestProtocol,
            newest: Self.newestProtocol
        )
        if let denial = check {
            channel.onText = nil
            channel.onClose = nil
            channel.send(denial.text)
            channel.close()
            hub.addRejected(rejection(of: hello, from: channel.address, denial))
            return
        }
        channel.send(PeekRemoteFrame.welcome(serverName: Self.serverName, serverVersion: serverVersion).text)
        open(hello, on: channel)
    }

    private func open(_ hello: PeekRemoteHello, on channel: PeekRemoteChannel) {
        let key = hello.sessionID
        // The app came back before the old socket noticed it was gone.
        if let previous = links[key]?.channel, previous !== channel {
            previous.onText = nil
            previous.onClose = nil
            previous.close()
        }
        links[key] = Link(channel: channel)
        known.insert(key)
        hub.connectSession(PeekLiveSession(
            key: key,
            info: hello.info,
            connection: .connected,
            address: channel.address,
            connectedAt: .now,
            droppedCount: 0
        ))
        channel.onText = { [weak self] text in self?.receive(text, in: key) }
        channel.onClose = { [weak self, weak channel] in
            guard let self, let channel, self.links[key]?.channel === channel else { return }
            self.links[key] = nil
            self.failBodyRequests(in: key, message: "The device disconnected before sending the body.")
            self.hub.disconnect(.live(key))
        }
        onOpen?(.live(key))
    }

    private func receive(_ text: String, in key: String) {
        guard let frame = try? PeekRemoteFrame(text: text), links[key] != nil else { return }
        let id = PeekSessionID.live(key)
        let inHistory = links[key]?.history != nil
        switch frame {
        case .entryAdded(let entry), .entryUpdated(let entry):
            if inHistory {
                links[key]?.history?.upsert(entry)
            } else if !hub.isPaused(id) || hub.entry(entry.id, in: id) != nil {
                // Paused keeps new calls out, but those already shown still finish.
                hub.upsertFromDevice(entry, in: id)
            }
        case .entryRemoved(let entryID):
            if inHistory { links[key]?.history?.remove(entryID) } else { hub.remove(entryID, in: id) }
        case .cleared:
            if inHistory { links[key]?.history?.clear() } else { hub.clear(id) }
        case .synced:
            guard let history = links[key]?.history else { return }
            links[key]?.history = nil
            hub.replaceEntries(history, in: id)
        case .dropped(let count):
            hub.addDropped(count, in: id)
        case .ping:
            links[key]?.channel.send(PeekRemoteFrame.pong.text)
        case .bodyResponse(let requestID, let body):
            guard let request = takeBodyRequest(requestID, from: key) else { return }
            if case .remote = body {
                hub.failBodyLoad(request.key, in: id, message: "The device sent the placeholder instead of the body.")
            } else {
                hub.completeBodyLoad(request.key, in: id, with: body)
            }
        case .bodyError(let requestID, let error, let message):
            guard let request = takeBodyRequest(requestID, from: key) else { return }
            hub.failBodyLoad(request.key, in: id, message: message ?? Self.describe(error))
        default:
            break
        }
    }

    /// An answer counts only from the session that was asked, and only once.
    private func takeBodyRequest(_ requestID: String, from session: String) -> BodyRequest? {
        guard bodyRequests[requestID]?.session == session else { return nil }
        return bodyRequests.removeValue(forKey: requestID)
    }

    private func failBodyRequests(in session: String, message: String) {
        for (requestID, request) in bodyRequests where request.session == session {
            bodyRequests[requestID] = nil
            hub.failBodyLoad(request.key, in: .live(session), message: message)
        }
    }

    private nonisolated static func describe(_ error: PeekRemoteBodyError) -> String {
        switch error {
        case .notFound: "The device no longer has this call."
        case .notHeld: "The device didn't keep this body."
        case .failed: "The device couldn't send the body."
        }
    }

    private func rejection(of hello: PeekRemoteHello, from address: String, _ denial: PeekRemoteFrame) -> PeekRejectedConnection {
        let reason: PeekRejectedConnection.Reason = if case .denied(.protocolVersion, _) = denial {
            .unsupportedProtocol(version: hello.protocolVersion)
        } else {
            .invalidToken
        }
        return PeekRejectedConnection(
            id: UUID().uuidString,
            address: address,
            name: hello.info.name,
            platform: hello.info.platform,
            reason: reason,
            at: .now
        )
    }
}

private extension Duration {
    nonisolated var seconds: Int { Int(components.seconds) }
}
