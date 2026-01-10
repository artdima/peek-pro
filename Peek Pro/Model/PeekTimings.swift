import Foundation

/// Phases follow HAR `timings`.
nonisolated struct PeekTimings: Hashable, Sendable {
    nonisolated enum Phase: String, CaseIterable, Sendable {
        case blocked
        case dns
        case connect
        case ssl
        case send
        case wait
        case receive
    }

    let blocked: Duration?
    let dns: Duration?
    let connect: Duration?
    let ssl: Duration?
    let send: Duration?
    let wait: Duration?
    let receive: Duration?

    init(
        blocked: Duration? = nil,
        dns: Duration? = nil,
        connect: Duration? = nil,
        ssl: Duration? = nil,
        send: Duration? = nil,
        wait: Duration? = nil,
        receive: Duration? = nil
    ) {
        self.blocked = blocked
        self.dns = dns
        self.connect = connect
        self.ssl = ssl
        self.send = send
        self.wait = wait
        self.receive = receive
    }

    subscript(phase: Phase) -> Duration? {
        switch phase {
        case .blocked: blocked
        case .dns: dns
        case .connect: connect
        case .ssl: ssl
        case .send: send
        case .wait: wait
        case .receive: receive
        }
    }

    var known: [(phase: Phase, duration: Duration)] {
        Phase.allCases.compactMap { phase in self[phase].map { (phase: phase, duration: $0) } }
    }
}
