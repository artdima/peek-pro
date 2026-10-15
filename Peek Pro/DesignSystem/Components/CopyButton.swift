import AppKit
import SwiftUI

struct CopyButton: View {
    let text: String
    var title = "Copy"
    var isBordered = false

    @State private var didCopy = false

    var body: some View {
        if isBordered {
            button.buttonStyle(.bordered)
        } else {
            button.buttonStyle(.borderless)
        }
    }

    private var button: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            didCopy = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                didCopy = false
            }
        } label: {
            Label(title, systemImage: didCopy ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
        }
        .labelStyle(.iconOnly)
        .help(title)
    }
}
