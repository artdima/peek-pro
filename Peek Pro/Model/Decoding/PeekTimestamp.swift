import Foundation

/// ISO 8601 time as the `.peek` format writes it, e.g. `2026-09-10T12:00:22.187500Z`.
nonisolated enum PeekTimestamp {
    // ISO8601DateFormatter stops at milliseconds, and the format carries microseconds.
    static func parse(_ text: String) -> Date? {
        let bytes = Array(text.utf8)
        var index = 0

        func digits(_ count: Int) -> Int? {
            guard index + count <= bytes.count else { return nil }
            var value = 0
            for _ in 0..<count {
                let digit = Int(bytes[index]) - 48
                guard (0...9).contains(digit) else { return nil }
                value = value * 10 + digit
                index += 1
            }
            return value
        }

        func skip(_ allowed: String) -> Bool {
            guard index < bytes.count, allowed.utf8.contains(bytes[index]) else { return false }
            index += 1
            return true
        }

        guard let year = digits(4), skip("-"),
              let month = digits(2), skip("-"),
              let day = digits(2), skip("Tt"),
              let hour = digits(2), skip(":"),
              let minute = digits(2), skip(":"),
              let second = digits(2),
              (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute), (0...60).contains(second)
        else { return nil }

        var fraction = 0.0
        if skip(".") {
            var scale = 0.1
            let start = index
            while index < bytes.count, (48...57).contains(bytes[index]) {
                fraction += Double(bytes[index] - 48) * scale
                scale /= 10
                index += 1
            }
            guard index > start else { return nil }
        }

        var offset = 0
        if skip("Zz") {
        } else if index < bytes.count, bytes[index] == UInt8(ascii: "+") || bytes[index] == UInt8(ascii: "-") {
            let sign = bytes[index] == UInt8(ascii: "-") ? -1 : 1
            index += 1
            guard let hours = digits(2) else { return nil }
            _ = skip(":")
            guard let minutes = digits(2) else { return nil }
            offset = sign * (hours * 3600 + minutes * 60)
        } else {
            return nil
        }
        guard index == bytes.count else { return nil }

        let seconds = daysSinceEpoch(year: year, month: month, day: day) * 86_400
            + hour * 3600 + minute * 60 + second - offset
        return Date(timeIntervalSince1970: TimeInterval(seconds) + fraction)
    }

    // Howard Hinnant's days_from_civil: no Calendar, so no locale or allocation per line.
    private static func daysSinceEpoch(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
