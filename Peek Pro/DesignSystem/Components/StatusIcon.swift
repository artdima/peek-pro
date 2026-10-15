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
            .statusForeground(entry.tint)
    }
}

private struct StatusForeground: ViewModifier {
    let color: Color?
    @Environment(\.backgroundProminence) private var prominence

    func body(content: Content) -> some View {
        content.foregroundStyle(prominence == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(color ?? .primary))
    }
}

extension View {
    func statusForeground(_ color: Color?) -> some View {
        modifier(StatusForeground(color: color))
    }
}
