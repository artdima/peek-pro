import SwiftUI

/// The capsule tab of Pulse: plain text, filled with the accent when selected.
struct PillButton: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                if let count {
                    Text("(\(count))")
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentColor : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
