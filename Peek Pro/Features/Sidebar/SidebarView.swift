import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        panelContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    NavigatorBar(selection: $model.panel)
                    Divider()
                }
            }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch model.panel {
        case .sessions:
            SessionsPanel()
        case .filters, .issues, .insights, .info:
            ContentUnavailableView(model.panel.title, systemImage: model.panel.symbol)
        }
    }
}

struct NavigatorBar: View {
    @Binding var selection: SidebarPanel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SidebarPanel.allCases) { panel in
                Button {
                    selection = panel
                } label: {
                    Image(systemName: panel.symbol)
                        .symbolVariant(selection == panel ? .fill : .none)
                        .foregroundStyle(selection == panel ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(panel.title)
                .keyboardShortcut(panel.shortcut, modifiers: .command)
                .accessibilityLabel(panel.title)
                .accessibilityAddTraits(selection == panel ? .isSelected : [])
            }
        }
        .font(.system(size: 14))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

#Preview {
    SidebarView()
        .environment(AppModel.preview(.live))
        .frame(width: 260, height: 500)
}
