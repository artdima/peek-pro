import Foundation

/// Polls rather than sleeping a fixed time: on a busy main actor a timer can fire after a fixed sleep ends.
/// A poll counts for at most 100 ms, so a long stall of the main actor doesn't use up the limit at once.
@MainActor
func eventually(within limit: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
    var waited = Duration.zero
    while !condition() {
        if waited >= limit { return false }
        let start = ContinuousClock.now
        try? await Task.sleep(for: .milliseconds(20))
        waited += min(ContinuousClock.now - start, .milliseconds(100))
    }
    return true
}
