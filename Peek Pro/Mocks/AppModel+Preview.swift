import Foundation

extension AppModel {
    static func preview(_ scenario: MockScenario) -> AppModel {
        AppModel(store: MockStore(scenario: scenario, isLive: false), restoresOpenFiles: false)
    }
}
