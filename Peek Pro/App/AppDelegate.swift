import AppKit

/// Owns the model so that files opened from Finder or the Dock reach it: with a `Window` scene and no
/// `DocumentGroup`, AppKit hands them to the delegate.
final class AppDelegate: NSObject, NSApplicationDelegate {
    // The test host mustn't take the port from a Peek Pro that's running.
    let model = AppModel(servesDevices: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil)

    func application(_ application: NSApplication, open urls: [URL]) {
        model.open(urls)
    }
}
