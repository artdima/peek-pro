import SwiftUI

struct AppThemePicker: View {
    @Binding var selection: AppTheme

    var body: some View {
        HStack(spacing: 13) {
            ForEach(AppTheme.allCases) { theme in
                AppThemeOption(theme: theme, isSelected: theme == selection) {
                    selection = theme
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct AppThemeOption: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AppThemeThumbnail(theme: theme)
                Text(theme.title)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .padding(.vertical, 3.5)
            .frame(maxWidth: 171.5)
            .background {
                if isSelected {
                    ZStack {
                        shape.fill(Color.accentColor.opacity(0.08))
                        shape.strokeBorder(Color.accentColor, lineWidth: 1)
                    }
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AppThemeThumbnail: View {
    let theme: AppTheme

    private static let size = CGSize(width: 46.5, height: 32.5)

    var body: some View {
        ZStack(alignment: .topLeading) {
            backdrop
            VStack(alignment: .leading, spacing: 4.75) {
                WindowButtons()
                if let palette {
                    SampleResponse(palette: palette)
                }
            }
            .padding(3.75)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
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
        HStack(spacing: 2.75) {
            dot(ThumbnailColor.close)
            dot(ThumbnailColor.minimize)
            dot(ThumbnailColor.zoom)
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 4.5, height: 4.5)
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
        .font(.system(size: 3.5, design: .monospaced))
        .fixedSize()
    }

    private func line(_ lead: String, _ leadColor: Color, _ rest: String, _ restColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: lead).foregroundStyle(leadColor)
            Text(verbatim: rest).foregroundStyle(restColor)
        }
        .frame(height: 4.5)
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
    @Previewable @State var theme = AppTheme.dark
    AppThemePicker(selection: $theme)
        .padding(20)
        .frame(width: 600)
}
