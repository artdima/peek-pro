import AppKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var appearanceName: NSAppearance.Name? {
        switch self {
        case .system: nil
        case .light: .aqua
        case .dark: .darkAqua
        }
    }

    static var current: AppTheme {
        stored(UserDefaults.standard.string(forKey: SettingsKey.appTheme))
    }

    static func stored(_ rawValue: String?) -> AppTheme {
        rawValue.flatMap(AppTheme.init(rawValue:)) ?? .system
    }

    func apply() {
        NSApp.appearance = appearanceName.flatMap(NSAppearance.init(named:))
    }
}
