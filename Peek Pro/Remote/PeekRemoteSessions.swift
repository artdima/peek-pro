import Foundation

/// Speaks the protocol with every device: the handshake, then one live session per app.
final class PeekRemoteSessions {
    nonisolated static let serverName = "Peek Pro"
    nonisolated static let oldestProtocol = PeekRemoteProtocol.version
    nonisolated static let newestProtocol = PeekRemoteProtocol.version

    /// A connection that hasn't said `hello` by then is closed.
    var helloTimeout = Duration.seconds(10)
    /// A session appeared, or came back.
    var onOpen: ((PeekSessionID) -> Void)?

    private let hub: SessionHub
    private let serverVersion: String?
    private var greeting: [ObjectIdentifier: PeekRemoteChannel] = [:]
    private var links: [String: Link] = [:]

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
                hub.upsert(CollectionOfOne(entry), in: id)
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
        default:
            break
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
