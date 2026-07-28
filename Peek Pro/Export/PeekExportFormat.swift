import Foundation

/// Mirrors `formatting.dart` from Peek core, so exported text reads the same whichever app wrote it.
/// The UI has its own, richer `PeekFormat`.
nonisolated enum PeekExportFormat {
    /// B, KB or MB with at most one decimal.
    static func bytes(_ bytes: Int) -> String {
        if bytes < 1_024 { return "\(bytes) B" }
        if bytes < 1_024 * 1_024 { return "\(trim(Double(bytes) / 1_024)) KB" }
        return "\(trim(Double(bytes) / (1_024 * 1_024))) MB"
    }

    /// µs, ms, s or m, coarser as it grows.
    static func duration(_ duration: Duration) -> String {
        let micros = duration.inMicroseconds
        if micros < 1_000 { return "\(micros) µs" }
        if micros < 1_000_000 { return "\(trim(Double(micros) / 1_000)) ms" }
        let seconds = micros / 1_000_000
        if seconds < 60 { return "\(trim(Double(micros) / 1_000_000)) s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }

    /// Dart's `DateTime.toUtc().toIso8601String()`: milliseconds, and microseconds only when there are some.
    static func timestamp(_ date: Date) -> String {
        let micros = date.microsecondsSince1970
        let seconds = micros.quotientAndRemainder(dividingBy: 1_000_000)
        let whole = seconds.remainder < 0 ? seconds.quotient - 1 : seconds.quotient
        let fraction = seconds.remainder < 0 ? seconds.remainder + 1_000_000 : seconds.remainder
        let components = Calendar.utc.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: Date(timeIntervalSince1970: TimeInterval(whole))
        )
        let base = String(
            format: "%04d-%02d-%02dT%02d:%02d:%02d",
            components.year ?? 0, components.month ?? 0, components.day ?? 0,
            components.hour ?? 0, components.minute ?? 0, components.second ?? 0
        )
        let milliseconds = String(format: "%03d", Int(fraction / 1_000))
        let rest = fraction % 1_000 == 0 ? "" : String(format: "%03d", Int(fraction % 1_000))
        return "\(base).\(milliseconds)\(rest)Z"
    }

    /// One decimal at most, none when it would be `.0`; halves round away from zero, as in Dart.
    private static func trim(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(format: "%.0f", rounded) : String(format: "%.1f", rounded)
    }
}

nonisolated extension Calendar {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
