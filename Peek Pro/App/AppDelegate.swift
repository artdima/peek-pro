import AppKit

/// Owns the model so that files opened from Finder or the Dock reach it: with a `Window` scene and no
/// `DocumentGroup`, AppKit hands them to the delegate.
final class AppDelegate: NSObject, NSApplicationDelegate {
    #if DEBUG
    // The test host mustn't take the port from a Peek Pro that's running.
    let model = AppModel(scenario: .waiting, servesDevices: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil)
    #else
    let model = AppModel(servesDevices: true)
    #endif

    func application(_ application: NSApplication, open urls: [URL]) {
        model.open(urls)
    }
}
