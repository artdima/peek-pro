import Foundation
import Network

/// Listens for devices on one port. What they say is up to whoever takes `onConnection`;
/// without it a connection just stays open.
final class PeekRemoteServer {
    nonisolated enum State: Hashable, Sendable {
        case idle
        case listening
        case portInUse
        case failed(String)
    }

    /// Whole bodies come back on request, so a frame can be as big as a downloaded file.
    nonisolated static let maximumMessageSize = 64 << 20
    nonisolated static let serviceType = "_peek._tcp"

    private(set) var port: Int
    private(set) var state = State.idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    private(set) var connections: [UUID: PeekRemoteConnection] = [:]
    /// The Bonjour name to advertise under; `nil` keeps quiet. Changes take effect on a running listener too.
    var serviceName: String? {
        didSet { if serviceName != oldValue { listener?.service = service } }
    }
    /// The name the network took — it may differ from `serviceName` when another desktop already has it.
    private(set) var registeredName: String? {
        didSet { if registeredName != oldValue { onServiceChange?(registeredName) } }
    }
    var onStateChange: ((State) -> Void)?
    var onServiceChange: ((String?) -> Void)?
    var onConnection: ((PeekRemoteConnection) -> Void)?

    private var listener: NWListener?

    init(port: Int = PeekServerState.defaultPort) {
        self.port = port
    }

    func start() {
        stop()
        guard (1...65_535).contains(port), let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            state = .failed("Port \(port) isn't valid.")
            return
        }
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        webSocket.maximumMessageSize = Self.maximumMessageSize
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        // Lets a restart take the port back while old connections sit in TIME_WAIT.
        parameters.allowLocalEndpointReuse = true

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: endpointPort)
        } catch {
            state = Self.state(for: error)
            return
        }
        self.listener = listener
        listener.service = service
        listener.serviceRegistrationUpdateHandler = { [weak self, weak listener] change in
            MainActor.assumeIsolated {
                guard let self, let listener, listener === self.listener else { return }
                self.serviceChanged(change)
            }
        }
        listener.stateUpdateHandler = { [weak self, weak listener] update in
            MainActor.assumeIsolated {
                guard let self, let listener, listener === self.listener else { return }
                self.listenerChanged(update)
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated {
                guard let self else { return connection.cancel() }
                self.accept(connection)
            }
        }
        listener.start(queue: .main)
    }

    /// Closes the listener and every connection.
    func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections.values { connection.close() }
        connections = [:]
        registeredName = nil
        state = .idle
    }

    func restart(on port: Int) {
        self.port = port
        start()
    }

    private var service: NWListener.Service? {
        serviceName.map {
            NWListener.Service(name: $0, type: Self.serviceType, txtRecord: NWTXTRecord(["protocolVersion": String(PeekRemoteProtocol.version)]))
        }
    }

    private func serviceChanged(_ change: NWListener.ServiceRegistrationChange) {
        switch change {
        case .add(let endpoint):
            if case .service(let name, _, _, _) = endpoint { registeredName = name }
        case .remove:
            registeredName = nil
        @unknown default:
            break
        }
    }

    private func listenerChanged(_ update: NWListener.State) {
        switch update {
        case .ready:
            state = .listening
        case .waiting(let error), .failed(let error):
            listener?.cancel()
            listener = nil
            registeredName = nil
            state = Self.state(for: error)
        case .setup, .cancelled:
            break
        @unknown default:
            break
        }
    }

    private func accept(_ nwConnection: NWConnection) {
        let connection = PeekRemoteConnection(nwConnection)
        connections[connection.id] = connection
        connection.onEnd = { [weak self, id = connection.id] in self?.connections[id] = nil }
        onConnection?(connection)
        connection.start()
    }

    private nonisolated static func state(for error: Error) -> State {
        if case .posix(.EADDRINUSE) = error as? NWError { return .portInUse }
        return .failed(error.localizedDescription)
    }
}

extension PeekRemoteServer {
    /// IPv4 addresses a device on the same network can reach, Wi-Fi and Ethernet first.
    nonisolated static func localAddresses() -> [String] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }

        var found: [(interface: String, address: String)] = []
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let item = pointer.pointee
            let flags = Int32(item.ifa_flags)
            guard let address = item.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET),
                  flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0
            else { continue }
            let interface = String(cString: item.ifa_name)
            // VPN tunnels and AirDrop links aren't reachable from a phone.
            guard !["utun", "awdl", "llw", "ipsec"].contains(where: interface.hasPrefix) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            let text = host.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
            found.append((interface, text))
        }
        let sorted = found.filter { $0.interface.hasPrefix("en") } + found.filter { !$0.interface.hasPrefix("en") }
        var seen: Set<String> = []
        return sorted.map(\.address).filter { seen.insert($0).inserted }
    }
}

/// One device's WebSocket. Text frames only: the protocol never sends binary.
final class PeekRemoteConnection: Identifiable, PeekRemoteChannel {
    let id = UUID()
    /// Where the device connects from, as a person would type it.
    let address: String
    var onText: ((String) -> Void)?
    /// Called once, whichever side closed.
    var onClose: (() -> Void)?
    private(set) var isOpen = true

    /// The server's bookkeeping, apart from `onClose` so the consumer can't replace it.
    fileprivate var onEnd: (() -> Void)?
    private let connection: NWConnection

    fileprivate init(_ connection: NWConnection) {
        self.connection = connection
        address = Self.address(of: connection.endpoint)
    }

    fileprivate func start() {
        connection.stateUpdateHandler = { [weak self] update in
            switch update {
            case .failed, .cancelled:
                MainActor.assumeIsolated { self?.finish() }
            default:
                break
            }
        }
        connection.start(queue: .main)
        receive()
    }

    func send(_ text: String) {
        guard isOpen else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        // A failed send fails the connection, and `stateUpdateHandler` reports that.
        connection.send(content: Data(text.utf8), contentContext: context, isComplete: true, completion: .idempotent)
    }

    /// Sends a close frame, then drops the connection.
    func close() {
        guard isOpen else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
        metadata.closeCode = .protocolCode(.normalClosure)
        let context = NWConnection.ContentContext(identifier: "close", metadata: [metadata])
        connection.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { [connection] _ in
            connection.cancel()
        })
        finish()
    }

    private func receive() {
        connection.receiveMessage { [weak self] content, context, _, error in
            let opcode = (context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata)?.opcode
            MainActor.assumeIsolated {
                guard let self, self.isOpen else { return }
                if error != nil || opcode == .close {
                    self.connection.cancel()
                    self.finish()
                    return
                }
                if opcode == .text {
                    self.onText?(String(decoding: content ?? Data(), as: UTF8.self))
                }
                self.receive()
            }
        }
    }

    private func finish() {
        guard isOpen else { return }
        isOpen = false
        onEnd?()
        onClose?()
        onEnd = nil
        onClose = nil
        onText = nil
    }

    /// IPv4 without the interface suffix; IPv4-mapped IPv6 as plain IPv4.
    nonisolated static func address(of endpoint: NWEndpoint) -> String {
        guard case .hostPort(let host, _) = endpoint else { return "\(endpoint)" }
        let text = switch host {
        case .ipv4(let address): "\(address)"
        case .ipv6(let address): address.asIPv4.map { "\($0)" } ?? "\(address)"
        case .name(let name, _): name
        @unknown default: "\(host)"
        }
        return String(text.prefix { $0 != "%" })
    }
}
