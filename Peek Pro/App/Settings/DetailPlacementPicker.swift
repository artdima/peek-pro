import AppKit
import SwiftUI

struct DetailPlacementPicker: View {
    @Binding var selection: DetailPlacement

    var body: some View {
        HStack(spacing: 12) {
            ForEach([DetailPlacement.bottom, .right]) { placement in
                PreviewChoice(
                    placement.title,
                    isSelected: placement == selection,
                    cornerRadius: DetailPlacementThumbnail.cornerRadius
                ) {
                    selection = placement
                } preview: {
                    DetailPlacementThumbnail(placement: placement)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }
}

private struct DetailPlacementThumbnail: View {
    let placement: DetailPlacement

    static let cornerRadius: CGFloat = 5
    private static let inset: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack(alignment: .topLeading) {
                Color(nsColor: .textBackgroundColor)
                if placement == .right {
                    rows([0.28, 0.40, 0.33, 0.37].map { $0 * width })
                    panel
                        .frame(width: width * 0.47, height: max(0, height - Self.inset * 2))
                        .offset(x: width * 0.51, y: Self.inset)
                } else {
                    rows([0.57, 0.81, 0.67, 0.75].map { $0 * width })
                    panel
                        .frame(width: max(0, width - Self.inset * 2), height: height * 0.4)
                        .offset(x: Self.inset, y: height * 0.52)
                }
            }
        }
        .frame(height: 76)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }

    private func rows(_ widths: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(widths.enumerated()), id: \.offset) { index, width in
                Capsule()
                    .fill(index == 0 ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.28)))
                    .frame(width: width, height: index == 0 ? 3.5 : 3)
            }
        }
        .padding(.top, Self.inset)
        .padding(.leading, Self.inset)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.primary.opacity(0.08))
    }
}

#Preview {
    @Previewable @State var placement = DetailPlacement.bottom
    DetailPlacementPicker(selection: $placement)
        .padding(20)
        .frame(width: 560)
}
