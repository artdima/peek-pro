import SwiftUI

struct PreviewChoice<Preview: View>: View {
    let title: String
    let isSelected: Bool
    let cornerRadius: CGFloat
    let action: () -> Void
    let preview: Preview

    private static var ringWidth: CGFloat { 2 }
    private static var ringGap: CGFloat { 2 }

    init(
        _ title: String,
        isSelected: Bool,
        cornerRadius: CGFloat,
        action: @escaping () -> Void,
        @ViewBuilder preview: () -> Preview
    ) {
        self.title = title
        self.isSelected = isSelected
        self.cornerRadius = cornerRadius
        self.action = action
        self.preview = preview()
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                preview
                    .padding(Self.ringWidth + Self.ringGap)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: cornerRadius + Self.ringWidth + Self.ringGap, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: Self.ringWidth)
                        }
                    }
                Text(title)
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
