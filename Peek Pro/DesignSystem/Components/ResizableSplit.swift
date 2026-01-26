import AppKit
import SwiftUI

/// A split whose divider position survives relaunches — `VSplitView` can't be told where to start.
struct ResizableSplit<Leading: View, Trailing: View>: View {
    let axis: Axis
    @Binding var fraction: Double
    let minLeading: CGFloat
    let minTrailing: CGFloat
    let leading: Leading
    let trailing: Trailing

    @State private var dragOrigin: CGFloat?

    init(
        axis: Axis,
        fraction: Binding<Double>,
        minLeading: CGFloat = 120,
        minTrailing: CGFloat = 120,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.axis = axis
        _fraction = fraction
        self.minLeading = minLeading
        self.minTrailing = minTrailing
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        GeometryReader { proxy in
            let total = axis == .vertical ? proxy.size.height : proxy.size.width
            let length = clamped(total * fraction, total: total)
            if axis == .vertical {
                VStack(spacing: 0) {
                    leading.frame(height: length)
                    divider(total: total, length: length)
                    trailing.frame(maxHeight: .infinity)
                }
            } else {
                HStack(spacing: 0) {
                    leading.frame(width: length)
                    divider(total: total, length: length)
                    trailing.frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func clamped(_ proposed: CGFloat, total: CGFloat) -> CGFloat {
        let upper = max(minLeading, total - minTrailing - 1)
        return min(max(proposed, minLeading), upper)
    }

    private func divider(total: CGFloat, length: CGFloat) -> some View {
        Rectangle()
            .fill(.separator)
            .frame(width: axis == .horizontal ? 1 : nil, height: axis == .vertical ? 1 : nil)
            .overlay {
                Color.clear
                    .frame(width: axis == .horizontal ? 9 : nil, height: axis == .vertical ? 9 : nil)
                    .contentShape(Rectangle())
                    .onHover { isInside in
                        if isInside { resizeCursor.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                let origin = dragOrigin ?? length
                                if dragOrigin == nil { dragOrigin = length }
                                let delta = axis == .vertical ? value.translation.height : value.translation.width
                                guard total > 0 else { return }
                                fraction = Double(clamped(origin + delta, total: total) / total)
                            }
                            .onEnded { _ in dragOrigin = nil }
                    )
            }
            .zIndex(1)
    }

    private var resizeCursor: NSCursor {
        axis == .vertical ? .rowResize : .columnResize
    }
}
