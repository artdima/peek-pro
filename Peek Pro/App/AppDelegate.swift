import AppKit

/// Owns the model so that files opened from Finder or the Dock reach it: with a `Window` scene and no
/// `DocumentGroup`, AppKit hands them to the delegate.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func application(_ application: NSApplication, open urls: [URL]) {
        model.open(urls)
    }
}
