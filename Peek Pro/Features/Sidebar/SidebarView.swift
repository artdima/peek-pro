import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        panelContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    NavigatorBar(selection: $model.panel, badges: [
                        .filters: model.filter.activeCount,
                        .issues: model.issues.filter { $0.severity == .error }.count,
                    ])
                    Divider()
                }
            }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch model.panel {
        case .sessions:
            SessionsPanel()
        case .filters:
            FiltersPanel()
        case .issues:
            IssuesPanel()
        case .insights:
            InsightsPanel()
        case .info:
            InfoPanel()
        }
    }
}

struct NavigatorBar: View {
    @Binding var selection: SidebarPanel
    var badges: [SidebarPanel: Int] = [:]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SidebarPanel.allCases) { panel in
                Button {
                    selection = panel
                } label: {
                    Image(systemName: panel.symbol)
                        .symbolVariant(selection == panel ? .fill : .none)
                        .foregroundStyle(selection == panel ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .overlay(alignment: .topTrailing) {
                            if let count = badges[panel], count > 0 {
                                Text(count, format: .number)
                                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .frame(minWidth: 14, minHeight: 14)
                                    .background(panel.badgeTint, in: Capsule())
                                    .offset(x: 9, y: -6)
                            }
                        }
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
