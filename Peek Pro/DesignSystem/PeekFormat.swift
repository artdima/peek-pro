import Foundation

/// Mirrors the formatting of Peek on the device, so both show the same numbers.
enum PeekFormat {
    static func bytes(_ count: Int) -> String {
        if count < 1_024 { return "\(count) B" }
        if count < 1_024 * 1_024 { return "\(trim(Double(count) / 1_024)) KB" }
        return "\(trim(Double(count) / (1_024 * 1_024))) MB"
    }

    static func duration(_ duration: Duration) -> String {
        let micros = Int((duration.timeInterval * 1_000_000).rounded())
        if micros < 1_000 { return "\(micros) µs" }
        if micros < 1_000_000 { return "\(trim(Double(micros) / 1_000)) ms" }
        let seconds = micros / 1_000_000
        if seconds < 60 { return "\(trim(Double(micros) / 1_000_000)) s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    /// "2 minutes ago", "just now" for the last minute.
    static func relative(_ date: Date, to now: Date = .now) -> String {
        if now.timeIntervalSince(date) < 60 { return "just now" }
        return date.formatted(.relative(presentation: .named))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private static func trim(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }
}
