import SwiftUI

struct DebugCommands: Commands {
    let model: AppModel

    @AppStorage(SettingsKey.appTheme) private var theme: AppTheme = .system

    var body: some Commands {
        #if DEBUG
        CommandMenu("Debug") {
            Section("Scenario") {
                ForEach(Array(MockScenario.allCases.enumerated()), id: \.element) { index, scenario in
                    Toggle(scenario.title, isOn: Binding(
                        get: { model.mocks?.scenario == scenario },
                        set: { _ in model.selectScenario(scenario) }
                    ))
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.control, .option])
                }
            }
            Divider()
            Picker("Appearance", selection: Binding(
                get: { theme },
                set: { theme = $0; $0.apply() }
            )) {
                ForEach(AppTheme.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        }
        #else
        EmptyCommands()
        #endif
    }
}
