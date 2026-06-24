import Foundation

extension AppModel {
    static func preview(_ scenario: MockScenario) -> AppModel {
        AppModel(scenario: scenario, isLive: false, restoresOpenFiles: false)
    }
}
