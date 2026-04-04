import AppKit
import SwiftUI

struct ImageBodyView: View {
    let data: Data
    @State private var isActualSize = false

    var body: some View {
        if let image = NSImage(data: data) {
            let pixels = Self.pixelSize(of: image)
            VStack(spacing: 0) {
                HStack {
                    Text("\(Int(pixels.width)) × \(Int(pixels.height)) px")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Zoom", selection: $isActualSize) {
                        Text("Fit").tag(false)
                        Text("Actual Size").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
                Group {
                    if isActualSize {
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: image)
                                .interpolation(.none)
                                .frame(width: image.size.width, height: image.size.height)
                                .padding(16)
                        }
                    } else {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: image.size.width, maxHeight: image.size.height)
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(Checkerboard())
            }
        } else {
            ContentUnavailableView("Can't Show the Image", systemImage: "photo.badge.exclamationmark",
                                   description: Text("The data isn't an image macOS can decode."))
        }
    }

    private static func pixelSize(of image: NSImage) -> CGSize {
        guard let representation = image.representations.first, representation.pixelsWide > 0 else { return image.size }
        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }
}

/// Shows where an image is transparent.
struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 8
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.primary.opacity(0.03)))
            var squares = Path()
            let rows = Int((size.height / cell).rounded(.up))
            let columns = Int((size.width / cell).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    squares.addRect(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
                }
            }
            context.fill(squares, with: .color(Color.primary.opacity(0.07)))
        }
    }
}

#Preview("PNG") {
    ImageBodyView(data: FixtureBodies.avatarPNG)
        .frame(width: 600, height: 400)
}

#Preview("Broken — Dark") {
    ImageBodyView(data: Data([0, 1, 2, 3]))
        .frame(width: 600, height: 300)
        .preferredColorScheme(.dark)
}
