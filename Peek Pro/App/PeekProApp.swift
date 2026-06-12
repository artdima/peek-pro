import SwiftUI

@main
struct PeekProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var model: AppModel { appDelegate.model }

    var body: some Scene {
        Window("Peek Pro", id: "main") {
            MainWindow()
                .environment(model)
        }
        .defaultSize(width: 1440, height: 900)

        WindowGroup("Request", id: "entry", for: EntryWindowID.self) { $windowID in
            if let windowID {
                EntryWindow(windowID: windowID)
                    .environment(model)
            }
        }
        .defaultSize(width: 1000, height: 720)
        .commandsRemoved()
        .commands {
            SidebarCommands()
            ToolbarCommands()
            AppCommands(model: model)
            DebugCommands(model: model)
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
