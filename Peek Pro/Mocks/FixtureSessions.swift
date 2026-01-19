import Foundation

enum FixtureSessions {
    static let shop = PeekApp(name: "Acme Shop", identifier: "dev.acme.shop", version: "3.4.0 (412)")
    static let admin = PeekApp(name: "Acme Admin", identifier: "dev.acme.admin", version: "1.2.0 (57)")

    static let iPhone = PeekDevice(name: "iPhone 16 Pro", model: "iPhone17,1", platform: .iOS, osVersion: "26.0", isSimulator: false)
    static let pixel = PeekDevice(name: "Pixel 9", model: "Google Pixel 9", platform: .android, osVersion: "16", isSimulator: false)
    static let iPad = PeekDevice(name: "iPad Air 11-inch (M3)", model: "iPad15,3", platform: .iOS, osVersion: "26.0", isSimulator: true)
    static let chrome = PeekDevice(name: "Chrome 141", model: nil, platform: .web, osVersion: "macOS 26.0", isSimulator: false)
    static let pixel8 = PeekDevice(name: "Pixel 8", model: "Google Pixel 8", platform: .android, osVersion: "15", isSimulator: false)

    static let peekVersion = "2.0.0"

    static let server = PeekServerState(
        status: .listening,
        port: 9741,
        addresses: ["192.168.1.10", "MacBook-Pro.local"],
        bonjourName: "Peek Pro on MacBook Pro",
        token: "k7q4-mx2p-9vd3"
    )

    static func info(_ app: PeekApp, _ device: PeekDevice, startedAt: Date) -> PeekSessionInfo {
        PeekSessionInfo(app: app, device: device, peekVersion: peekVersion, startedAt: startedAt)
    }

    static let iPhoneSession = PeekLiveSession(
        key: "iphone",
        info: info(shop, iPhone, startedAt: Fixtures.start.addingTimeInterval(-2)),
        connection: .connected,
        address: "192.168.1.23",
        connectedAt: Fixtures.start.addingTimeInterval(-2),
        disconnectedAt: nil,
        droppedCount: 0
    )

    static let pixelSession = PeekLiveSession(
        key: "pixel",
        info: info(shop, pixel, startedAt: Fixtures.start.addingTimeInterval(-300)),
        connection: .connected,
        address: "127.0.0.1",
        connectedAt: Fixtures.start.addingTimeInterval(-300),
        disconnectedAt: nil,
        droppedCount: 37
    )

    static let chromeSession = PeekLiveSession(
        key: "chrome",
        info: info(admin, chrome, startedAt: Fixtures.start.addingTimeInterval(60)),
        connection: .connecting,
        address: "127.0.0.1",
        connectedAt: Fixtures.start.addingTimeInterval(60),
        disconnectedAt: nil,
        droppedCount: 0
    )

    static let iPadSession = PeekLiveSession(
        key: "ipad",
        info: info(shop, iPad, startedAt: Fixtures.start.addingTimeInterval(-3_600)),
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
        info: info(shop, iPhone, startedAt: Fixtures.start.addingTimeInterval(-73_000)),
        formatVersion: 1,
        skippedLines: 0
    )

    static let bugReport = PeekSessionFile(
        url: URL(filePath: "/Users/Shared/Peek/checkout-crash.peek"),
        byteCount: 48_120,
        modifiedAt: Fixtures.start.addingTimeInterval(-259_200),
        info: info(shop, pixel8, startedAt: Fixtures.start.addingTimeInterval(-260_000)),
        formatVersion: 1,
        skippedLines: 2
    )

    static let rejected: [PeekRejectedConnection] = [
        PeekRejectedConnection(
            id: "r1",
            address: "192.168.1.41",
            appName: "Acme Shop",
            deviceName: "Galaxy S24",
            reason: .invalidToken,
            at: Fixtures.start.addingTimeInterval(-40)
        ),
        PeekRejectedConnection(
            id: "r2",
            address: "192.168.1.57",
            appName: "Acme Courier",
            deviceName: "iPhone 13",
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
