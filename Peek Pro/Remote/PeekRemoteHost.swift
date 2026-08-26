import Foundation
import Network

/// Runs the server on the port from Settings and mirrors its state into the hub.
final class PeekRemoteHost {
    /// How often a taken port is tried again, so quitting the other app is enough.
    nonisolated static let retryInterval = Duration.seconds(5)

    let server: PeekRemoteServer
    let sessions: PeekRemoteSessions
    private let hub: SessionHub
    private let pathMonitor = NWPathMonitor()
    private var retry: Task<Void, Never>?

    init(hub: SessionHub) {
        self.hub = hub
        server = PeekRemoteServer(port: hub.server.port)
        let sessions = PeekRemoteSessions(hub: hub)
        self.sessions = sessions
        server.onConnection = { sessions.accept($0) }
        server.onStateChange = { [weak self] _ in
            self?.publish()
            self?.retryIfNeeded()
        }
    }

    func start() {
        server.start()
        // Addresses change as Wi-Fi comes and goes.
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            MainActor.assumeIsolated { self?.publish() }
        }
        pathMonitor.start(queue: .main)
    }

    /// After Settings changed the port.
    func applySettings() {
        guard hub.server.port != server.port else { return }
        server.restart(on: hub.server.port)
    }

    /// Writes the real state over whatever a mock scenario showed.
    func publish() {
        var state = hub.server
        state.port = server.port
        state.status = server.state == .listening || server.state == .idle ? .listening : .portInUse
        state.addresses = PeekRemoteServer.localAddresses()
        hub.setServer(state)
    }

    private func retryIfNeeded() {
        retry?.cancel()
        guard server.state == .portInUse else { return }
        retry = Task { [weak self] in
            try? await Task.sleep(for: Self.retryInterval)
            guard !Task.isCancelled, let self, self.server.state == .portInUse else { return }
            self.server.start()
        }
    }
}
