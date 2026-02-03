import SwiftUI

enum DetailPlacement: String, CaseIterable, Identifiable {
    case bottom
    case right
    case hidden

    static let storageKey = "detailPlacement"

    var id: Self { self }

    var title: String {
        switch self {
        case .bottom: "Details at Bottom"
        case .right: "Details on Right"
        case .hidden: "Hide Details"
        }
    }

    var symbol: String {
        switch self {
        case .bottom: "rectangle.split.1x2"
        case .right: "rectangle.split.2x1"
        case .hidden: "rectangle"
        }
    }
}

struct ConsoleSplitView: View {
    let placement: DetailPlacement

    @AppStorage("consoleSplit.bottom") private var bottomFraction = 0.55
    @AppStorage("consoleSplit.right") private var rightFraction = 0.5

    var body: some View {
        switch placement {
        case .bottom:
            ResizableSplit(axis: .vertical, fraction: $bottomFraction, minLeading: 160, minTrailing: 200) {
                ConsolePlaceholder()
            } trailing: {
                RequestDetailPlaceholder()
            }
        case .right:
            ResizableSplit(axis: .horizontal, fraction: $rightFraction, minLeading: 380, minTrailing: 340) {
                ConsolePlaceholder()
            } trailing: {
                RequestDetailPlaceholder()
            }
        case .hidden:
            ConsolePlaceholder()
        }
    }
}

struct DetailPlacementMenu: View {
    @Binding var placement: DetailPlacement

    var body: some View {
        Menu {
            Picker("Details", selection: $placement) {
                ForEach(DetailPlacement.allCases) { placement in
                    Label(placement.title, systemImage: placement.symbol).tag(placement)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Layout", systemImage: placement.symbol)
        }
        .help("Layout")
    }
}

private struct ConsolePlaceholder: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Requests", systemImage: "list.bullet.rectangle")
        } description: {
            Text("\(model.selectedEntries.count) requests in \(model.windowTitle)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RequestDetailPlaceholder: View {
    var body: some View {
        ContentUnavailableView("No Request Selected", systemImage: "network")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Bottom") {
    ConsoleSplitView(placement: .bottom)
        .environment(AppModel.preview(.live))
        .frame(width: 900, height: 600)
}

#Preview("Right") {
    ConsoleSplitView(placement: .right)
        .environment(AppModel.preview(.live))
        .frame(width: 1100, height: 600)
}
