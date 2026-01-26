import SwiftUI

@main
struct PeekProApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Peek Pro", id: "main") {
            MainWindow()
                .environment(model)
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            DebugCommands(model: model)
        }
    }
}
