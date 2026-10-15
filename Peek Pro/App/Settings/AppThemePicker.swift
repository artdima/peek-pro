import SwiftUI

struct AppThemePicker: View {
    @Binding var selection: AppTheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTheme.allCases) { theme in
                PreviewChoice(
                    theme.title,
                    isSelected: theme == selection,
                    cornerRadius: AppThemeThumbnail.cornerRadius
                ) {
                    selection = theme
                } preview: {
                    AppThemeThumbnail(theme: theme)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }
}

private struct AppThemeThumbnail: View {
    let theme: AppTheme

    static let cornerRadius: CGFloat = 5
    private static let size = CGSize(width: 92, height: 57)

    var body: some View {
        ZStack(alignment: .topLeading) {
            backdrop
            VStack(alignment: .leading, spacing: 9.5) {
                WindowButtons()
                if let palette {
                    SampleResponse(palette: palette)
                }
            }
            .padding(7.5)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var backdrop: some View {
        switch theme {
        case .system:
            ZStack {
                ThumbnailColor.darkBackground
                Path { path in
                    path.move(to: CGPoint(x: Self.size.width, y: 0))
                    path.addLine(to: CGPoint(x: Self.size.width, y: Self.size.height))
                    path.addLine(to: CGPoint(x: 0, y: Self.size.height))
                    path.closeSubpath()
                }
                .fill(ThumbnailColor.systemLightHalf)
            }
        case .light:
            ThumbnailColor.lightBackground
        case .dark:
            ThumbnailColor.darkBackground
        }
    }

    private var palette: SamplePalette? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct WindowButtons: View {
    var body: some View {
        HStack(spacing: 5.5) {
            dot(ThumbnailColor.close)
            dot(ThumbnailColor.minimize)
            dot(ThumbnailColor.zoom)
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
    }
}

private struct SampleResponse: View {
    let palette: SamplePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            line("HTTP/1.1", palette.plain, " OK 200", palette.status)
            line("Vary:", palette.name, " Origin", palette.value)
            line("Connection:", palette.name, " close", palette.value)
        }
        .font(.system(size: 7, design: .monospaced))
        .fixedSize()
    }

    private func line(_ lead: String, _ leadColor: Color, _ rest: String, _ restColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: lead).foregroundStyle(leadColor)
            Text(verbatim: rest).foregroundStyle(restColor)
        }
        .frame(height: 9)
    }
}

private struct SamplePalette {
    let plain: Color
    let status: Color
    let name: Color
    let value: Color

    static let light = SamplePalette(
        plain: Color(rgb: 0x1F1F1F),
        status: Color(rgb: 0x66CB65),
        name: Color(rgb: 0x94704A),
        value: Color(rgb: 0x4BB2F6)
    )

    static let dark = SamplePalette(
        plain: Color(rgb: 0xE3E4E4),
        status: Color(rgb: 0x56B44D),
        name: Color(rgb: 0xA0D3B6),
        value: Color(rgb: 0xC37365)
    )
}

private enum ThumbnailColor {
    static let darkBackground = Color(rgb: 0x272828)
    static let lightBackground = Color(rgb: 0xF5F6F6)
    static let systemLightHalf = Color(rgb: 0xD8D8D8)
    static let close = Color(rgb: 0xEC665A)
    static let minimize = Color(rgb: 0xE1C14C)
    static let zoom = Color(rgb: 0x72BF47)
}

private extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#Preview {
    @Previewable @State var theme = AppTheme.system
    AppThemePicker(selection: $theme)
        .padding(20)
        .frame(width: 600)
}
