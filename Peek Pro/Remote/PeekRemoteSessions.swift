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
    /// A device quiet this long gets a `ping`…
    var heartbeatInterval = Duration.seconds(10)
    /// …and one that stays silent this long after the `ping` is gone, even if the socket never said so
    /// (Wi-Fi dropped, phone asleep). Measured from the ping, so a Mac waking from sleep asks before it drops anyone.
    var answerLimit = Duration.seconds(20)
    /// A session appeared, or came back.
    var onOpen: ((PeekSessionID) -> Void)?

    /// How long a pairing code stays good; a new one takes over when it runs out.
    var codeLifetime = PeekPairingCode.defaultLifetime {
        didSet { rotateCode() }
    }
    /// Wrong codes before the code changes, so a guess can't work through all ten thousand.
    var codeFailureLimit = 5

    /// Tells this desktop from others across launches, so a device knows whose token it holds.
    let serverID: String
    let pairedDevices: PeekPairedDevices
    private let hub: SessionHub
    private let serverVersion: String?
    private var codeFailures = 0
    private var codeExpiry: Task<Void, Never>?
    private var greeting: [ObjectIdentifier: PeekRemoteChannel] = [:]
    private var links: [String: Link] = [:]
    /// Sessions this server opened, connected or not: the ones whose bodies it fetches.
    private var known: Set<String> = []
    private var bodyRequests: [String: BodyRequest] = [:]
    private var lastRequestID = 0
    /// Sessions disconnected here: the app would reconnect on its own, so it's turned away until it restarts.
    private var blocked: Set<String> = []
    private var heartbeat: Task<Void, Never>?

    private struct BodyRequest {
        let session: String
        let key: PeekBodyLoadKey
    }

    private struct Link {
        let channel: PeekRemoteChannel
        /// The paired device behind the connection, when it came with a device token.
        var deviceID: String?
        /// The history until `synced`, shown in one go rather than call by call.
        var history: SessionStore? = SessionStore()
        var lastHeard = ContinuousClock.now
        /// The unanswered `ping`, if one is out.
        var pingedAt: ContinuousClock.Instant?
    }

    init(
        hub: SessionHub,
        serverVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        serverID: String = PeekRemoteSessions.storedServerID(),
        pairedDevices: PeekPairedDevices = InMemoryPairedDevices()
    ) {
        self.hub = hub
        self.serverVersion = serverVersion
        self.serverID = serverID
        self.pairedDevices = pairedDevices
        hub.setPairedDevices(pairedDevices.devices)
        rotateCode()
    }

    /// Made once and kept in the defaults, so a device's token survives a relaunch.
    static func storedServerID() -> String {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: SettingsKey.serverID), !id.isEmpty { return id }
        let id = UUID().uuidString.lowercased()
        defaults.set(id, forKey: SettingsKey.serverID)
        return id
    }

    /// A fresh code, now: after a pairing, too many wrong tries, the old one running out, or a click.
    func rotateCode() {
        hub.rotatePairingCode(lifetime: codeLifetime)
        codeFailures = 0
        codeExpiry?.cancel()
        let lifetime = codeLifetime
        codeExpiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(lifetime))
            guard !Task.isCancelled, let self else { return }
            self.rotateCode()
        }
    }

    /// Forgets the device's token and closes its session: when the app comes back with the old token it is
    /// turned away with `denied(token)`, which is what makes it ask for a code again.
    func forgetDevice(_ id: String) {
        pairedDevices.remove(id)
        hub.removePairedDevice(id)
        for link in links.values where link.deviceID == id { link.channel.close() }
    }

    func forgetAllDevices() {
        for device in pairedDevices.devices { forgetDevice(device.id) }
    }

    var connectedCount: Int { links.count }

    /// Closes the connection and turns the app away if it comes back; `false` if it isn't connected here.
    @discardableResult
    func disconnect(_ id: PeekSessionID) -> Bool {
        guard case .live(let key) = id, let channel = links[key]?.channel else { return false }
        blocked.insert(key)
        channel.close()
        return true
    }

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

        // A code that ran out before the timer noticed is as good as a wrong one.
        if hello.code != nil, hub.server.pairingCode.isExpired() { rotateCode() }
        let check = PeekRemoteProtocol.check(
            hello,
            token: hub.server.token,
            code: hub.server.pairingCode.digits,
            deviceTokens: pairedDevices.tokens.keys,
            oldest: Self.oldestProtocol,
            newest: Self.newestProtocol
        )
        if let denial = check {
            channel.onText = nil
            channel.onClose = nil
            channel.send(denial.text)
            channel.close()
            hub.addRejected(rejection(of: hello, from: channel.address, denial))
            if case .denied(.code, _) = denial {
                codeFailures += 1
                if codeFailures >= codeFailureLimit { rotateCode() }
            }
            return
        }
        if blocked.contains(hello.sessionID) {
            channel.onText = nil
            channel.onClose = nil
            channel.send(PeekRemoteFrame.denied(.other, message: "Disconnected in Peek Pro. Restart the app to connect again.").text)
            channel.close()
            return
        }
        var deviceID = hello.token.flatMap { pairedDevices.tokens[$0] }
        var issued: String?
        if hello.code != nil {
            // The code is spent; from now on the device carries a token of its own.
            let token = Self.newDeviceToken()
            let device = PeekPairedDevice(
                id: UUID().uuidString.lowercased(),
                name: hello.info.name,
                platform: hello.info.platform,
                address: channel.address,
                pairedAt: .now,
                lastSeenAt: .now
            )
            pairedDevices.add(device, token: token)
            hub.addPairedDevice(device)
            deviceID = device.id
            issued = token
            rotateCode()
        } else if let deviceID {
            hub.touchPairedDevice(deviceID, address: channel.address)
            if let device = hub.pairedDevices.first(where: { $0.id == deviceID }) { pairedDevices.update(device) }
        }
        channel.send(PeekRemoteFrame.welcome(
            serverName: Self.serverName,
            serverVersion: serverVersion,
            serverID: serverID,
            deviceToken: issued
        ).text)
        open(hello, on: channel, deviceID: deviceID)
    }

    /// 32 random bytes as hex; long enough that guessing is not a plan.
    private nonisolated static func newDeviceToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }

    private func open(_ hello: PeekRemoteHello, on channel: PeekRemoteChannel, deviceID: String?) {
        let key = hello.sessionID
        // The app came back before the old socket noticed it was gone.
        if let previous = links[key]?.channel, previous !== channel {
            previous.onText = nil
            previous.onClose = nil
            previous.close()
        }
        links[key] = Link(channel: channel, deviceID: deviceID)
        known.insert(key)
        hub.connectSession(PeekLiveSession(
            key: key,
            info: hello.info,
            connection: .connected,
            address: channel.address,
            connectedAt: .now,
            droppedCount: 0,
            pairedDeviceID: deviceID
        ))
        channel.onText = { [weak self] text in self?.receive(text, in: key) }
        channel.onClose = { [weak self, weak channel] in
            guard let self, let channel, self.links[key]?.channel === channel else { return }
            self.links[key] = nil
            self.failBodyRequests(in: key, message: "The device disconnected before sending the body.")
            self.hub.disconnect(.live(key))
        }
        onOpen?(.live(key))
        startHeartbeat()
    }

    private func receive(_ text: String, in key: String) {
        guard links[key] != nil else { return }
        links[key]?.lastHeard = .now
        links[key]?.pingedAt = nil
        guard let frame = try? PeekRemoteFrame(text: text) else { return }
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

    private func startHeartbeat() {
        guard heartbeat == nil else { return }
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = self?.heartbeatInterval else { return }
                try? await Task.sleep(for: interval / 2)
                guard let self else { return }
                if !self.beat() {
                    self.heartbeat = nil
                    return
                }
            }
        }
    }

    /// Pings quiet devices and closes those that didn't answer; `false` once nobody is left to watch.
    private func beat() -> Bool {
        let now = ContinuousClock.now
        for (key, link) in links {
            if let pingedAt = link.pingedAt {
                if now - pingedAt >= answerLimit { link.channel.close() }
            } else if now - link.lastHeard >= heartbeatInterval {
                links[key]?.pingedAt = now
                link.channel.send(PeekRemoteFrame.ping.text)
            }
        }
        return !links.isEmpty
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
        let reason: PeekRejectedConnection.Reason = switch denial {
        case .denied(.protocolVersion, _): .unsupportedProtocol(version: hello.protocolVersion)
        case .denied(.code, _): .wrongCode
        default: .invalidToken
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
