import SwiftUI

/// Version 1 shows only the sessions; Filters, Issues, Insights and Info wait for a later release.
struct SidebarView: View {
    var body: some View {
        SessionsPanel()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SidebarView()
        .environment(AppModel.preview(.live))
        .frame(width: 260, height: 500)
}
