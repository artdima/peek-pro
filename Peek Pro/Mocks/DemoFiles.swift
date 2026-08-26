import Foundation

extension SessionHub {
    /// The demo files behind "Open Demo Session", kept in release builds too.
    func addDemoFiles() {
        addDemoFile(FixtureSessions.savedSession, entries: Fixtures.copies(of: Fixtures.session, prefix: "saved", shiftedBy: -73_000))
        addDemoFile(FixtureSessions.bugReport, entries: FixtureSessions.bugReportEntries)
    }
}
