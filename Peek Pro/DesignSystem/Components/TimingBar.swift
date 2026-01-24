import SwiftUI

/// A phase drawn inside the whole call: `start` and `length` are fractions of the total.
struct TimingBar: View {
    let start: Double
    let length: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let origin = min(max(start, 0), 1)
            let width = max(2, proxy.size.width * min(length, 1 - origin))
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: width, height: proxy.size.height)
                .offset(x: proxy.size.width * origin)
        }
        .frame(height: 10)
    }
}
