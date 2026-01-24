import SwiftUI

struct StatusIcon: View {
    let entry: PeekEntry

    var body: some View {
        if entry.state == .pending {
            ProgressView()
                .controlSize(.mini)
        } else {
            Image(systemName: entry.statusSymbol)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, entry.tint)
        }
    }
}

struct StatusLabel: View {
    let entry: PeekEntry

    var body: some View {
        Text(entry.statusTitle)
            .fontWeight(.semibold)
            .foregroundStyle(entry.tint)
    }
}
