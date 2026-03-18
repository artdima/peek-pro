import SwiftUI

struct QuickModeBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let entries = model.filteredEntries
        HStack(spacing: 2) {
            ForEach(ConsoleQuickMode.allCases) { mode in
                PillButton(title: mode.title, count: mode.count(in: entries), isSelected: model.quickMode == mode) {
                    model.quickMode = mode
                }
            }
            Spacer()
            StatusLegendButton()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private struct StatusLegendButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .help("What the colors mean")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            StatusLegend()
        }
    }
}

private struct StatusLegend: View {
    private let items: [(title: String, color: Color)] = [
        ("2xx — success", Color(.statusSuccess)),
        ("3xx — redirect", Color(.statusRedirect)),
        ("4xx — client error", Color(.statusClientError)),
        ("5xx — server error", Color(.statusServerError)),
        ("Failed — timeout, connection, certificate", Color(.statusFailure)),
        ("Pending or cancelled", Color(.statusNeutral)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status Colors")
                .font(.headline)
            ForEach(items, id: \.title) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 9, height: 9)
                    Text(item.title)
                }
            }
            Divider()
            Label("Rows in red failed or got a 4xx/5xx.", systemImage: "exclamationmark.circle")
            Label("Durations in orange took 3 s or longer.", systemImage: "tortoise")
        }
        .font(.callout)
        .padding(14)
        .frame(width: 300, alignment: .leading)
    }
}
