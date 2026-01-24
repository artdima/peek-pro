import AppKit
import SwiftUI

struct CopyButton: View {
    let text: String
    var title = "Copy"

    @State private var didCopy = false

    var body: some View {
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
        .buttonStyle(.borderless)
        .help(title)
    }
}
