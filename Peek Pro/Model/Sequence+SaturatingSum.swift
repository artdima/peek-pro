import Foundation

nonisolated extension Sequence<Int> {
    func saturatingSum() -> Int {
        reduce(0) { total, value in
            let (sum, overflow) = total.addingReportingOverflow(value)
            return overflow ? (value > 0 ? .max : .min) : sum
        }
    }
}
