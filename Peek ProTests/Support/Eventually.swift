import Foundation

/// Polls rather than sleeping a fixed time: on a busy main actor a timer can fire after a fixed sleep ends.
@MainActor
func eventually(within limit: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + limit
    while !condition() {
        if ContinuousClock.now >= deadline { return false }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return true
}
