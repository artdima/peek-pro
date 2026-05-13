import Foundation

enum FixtureSessions {
    static let peekVersion = "2.0.0"

    static let server = PeekServerState(
        status: .listening,
        port: 9741,
        addresses: ["192.168.1.10", "MacBook-Pro.local"],
        bonjourName: "Peek Pro on MacBook Pro",
        token: "k7q4-mx2p-9vd3"
    )

    static func info(_ name: String?, _ platform: PeekPlatform, _ osVersion: String? = nil, startedAt: Date) -> PeekSessionInfo {
        PeekSessionInfo(name: name, platform: platform, osVersion: osVersion, peekVersion: peekVersion, startedAt: startedAt)
    }

    static let iPhoneSession = PeekLiveSession(
        key: "iphone",
        info: info("Acme Shop", .iOS, "26.0", startedAt: Fixtures.start.addingTimeInterval(-2)),
        connection: .connected,
        address: "192.168.1.23",
        connectedAt: Fixtures.start.addingTimeInterval(-2),
        disconnectedAt: nil,
        droppedCount: 0
    )

    static let pixelSession = PeekLiveSession(
        key: "pixel",
        info: info("Acme Shop", .android, startedAt: Fixtures.start.addingTimeInterval(-300)),
        connection: .connected,
        address: "127.0.0.1",
        connectedAt: Fixtures.start.addingTimeInterval(-300),
        disconnectedAt: nil,
        droppedCount: 37
    )

    static let chromeSession = PeekLiveSession(
        key: "chrome",
        info: info("Acme Admin", .web, startedAt: Fixtures.start.addingTimeInterval(60)),
        connection: .connecting,
        address: "127.0.0.1",
        connectedAt: Fixtures.start.addingTimeInterval(60),
        disconnectedAt: nil,
        droppedCount: 0
    )

    static let iPadSession = PeekLiveSession(
        key: "ipad",
        info: info(nil, .iOS, "26.0", startedAt: Fixtures.start.addingTimeInterval(-3_600)),
        connection: .disconnected,
        address: "127.0.0.1",
        connectedAt: Fixtures.start.addingTimeInterval(-3_600),
        disconnectedAt: Fixtures.start.addingTimeInterval(-3_000),
        droppedCount: 0
    )

    static let savedSession = PeekSessionFile(
        url: URL(filePath: "/Users/Shared/Peek/peek-acme-shop-2026-09-22T18-41.peek"),
        byteCount: 217_344,
        modifiedAt: Fixtures.start.addingTimeInterval(-72_000),
        info: info("Acme Shop", .iOS, "26.0", startedAt: Fixtures.start.addingTimeInterval(-73_000)),
        formatVersion: 1,
        skippedLines: 0
    )

    static let bugReport = PeekSessionFile(
        url: URL(filePath: "/Users/Shared/Peek/checkout-crash.peek"),
        byteCount: 48_120,
        modifiedAt: Fixtures.start.addingTimeInterval(-259_200),
        info: info("Acme Shop", .android, startedAt: Fixtures.start.addingTimeInterval(-260_000)),
        formatVersion: 1,
        skippedLines: 2
    )

    static let futureFile = PeekSessionFile(
        url: URL(filePath: "/Users/Shared/Peek/from-peek-2.1.peek"),
        byteCount: 96_310,
        modifiedAt: Fixtures.start.addingTimeInterval(-3_600),
        info: info("Acme Shop", .iOS, "26.1", startedAt: Fixtures.start.addingTimeInterval(-4_000)),
        formatVersion: 2,
        skippedLines: 0
    )

    static let legacyFile = PeekSessionFile(
        url: URL(filePath: "/Users/Shared/Peek/prerelease-demo.peek"),
        byteCount: 12_004,
        modifiedAt: Fixtures.start.addingTimeInterval(-2_592_000),
        info: PeekSessionInfo(name: nil, platform: .android, osVersion: nil, peekVersion: "1.9.0-dev", startedAt: Fixtures.start.addingTimeInterval(-2_600_000)),
        formatVersion: 0,
        skippedLines: 0,
        failure: .unsupportedFormat(version: 0)
    )

    static let futureFileEntries = Fixtures.copies(
        of: Array(Fixtures.session.suffix(14)),
        prefix: "future",
        shiftedBy: -3_900
    )

    static let rejected: [PeekRejectedConnection] = [
        PeekRejectedConnection(
            id: "r1",
            address: "192.168.1.41",
            name: "Acme Shop",
            platform: .android,
            reason: .invalidToken,
            at: Fixtures.start.addingTimeInterval(-40)
        ),
        PeekRejectedConnection(
            id: "r2",
            address: "192.168.1.57",
            name: nil,
            platform: .iOS,
            reason: .unsupportedProtocol(version: 3),
            at: Fixtures.start.addingTimeInterval(-15)
        ),
    ]

    static let pixelEntries = Fixtures.copies(
        of: Fixtures.session.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element),
        prefix: "px",
        shiftedBy: -240
    )

    static let iPadEntries = Fixtures.copies(
        of: Array(Fixtures.session.prefix(12)),
        prefix: "ipad",
        shiftedBy: -3_500
    )

    static let bugReportEntries = Fixtures.copies(
        of: Fixtures.session.filter { $0.isError || $0.isPinned },
        prefix: "bug",
        shiftedBy: -259_900
    )
}
