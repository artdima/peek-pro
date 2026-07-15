import Foundation

nonisolated extension RandomAccessCollection {
    /// The first index whose element is not `belongsBefore`; the collection must be partitioned that way.
    func partitioningIndex(where belongsBefore: (Element) -> Bool) -> Index {
        var low = startIndex
        var count = self.count
        while count > 0 {
            let half = count / 2
            let middle = index(low, offsetBy: half)
            if belongsBefore(self[middle]) {
                low = index(after: middle)
                count -= half + 1
            } else {
                count = half
            }
        }
        return low
    }
}
