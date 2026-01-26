import AppKit
import SwiftUI

struct DebugCommands: Commands {
    let model: AppModel

    var body: some Commands {
        #if DEBUG
        CommandMenu("Debug") {
            Section("Scenario") {
                ForEach(Array(MockScenario.allCases.enumerated()), id: \.element) { index, scenario in
                    Toggle(scenario.title, isOn: Binding(
                        get: { model.store.scenario == scenario },
                        set: { _ in model.selectScenario(scenario) }
                    ))
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.control, .option])
                }
            }
            Divider()
            Picker("Appearance", selection: Binding(
                get: { DebugAppearance.current },
                set: { $0.apply() }
            )) {
                ForEach(DebugAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
        }
        #else
        EmptyCommands()
        #endif
    }
}

enum DebugAppearance: String, CaseIterable, Identifiable {
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

    static var current: DebugAppearance {
        let name = NSApp.appearance?.name
        if name == .aqua { return .light }
        if name == .darkAqua { return .dark }
        return .system
    }

    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
