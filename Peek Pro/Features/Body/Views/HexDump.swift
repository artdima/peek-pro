import Foundation

nonisolated enum HexDump {
    static let limit = 4 * 1_024

    /// `offset  xx xx … xx  xx … xx  |ascii|`, sixteen bytes a line, like `hexdump -C`.
    static func format(_ data: Data) -> String {
        let bytes = Array(data.prefix(limit))
        var lines: [String] = []
        lines.reserveCapacity(bytes.count / 16 + 1)
        for offset in stride(from: 0, to: bytes.count, by: 16) {
            let chunk = bytes[offset..<min(offset + 16, bytes.count)]
            var hex = ""
            for (index, byte) in chunk.enumerated() {
                if index == 8 { hex += " " }
                hex += String(format: "%02x ", byte)
            }
            let width = 16 * 3 + 1
            hex += String(repeating: " ", count: max(0, width - hex.count))
            let ascii = String(chunk.map { (0x20...0x7E).contains($0) ? Character(Unicode.Scalar($0)) : "." })
            lines.append(String(format: "%08lx  ", offset) + hex + " |" + ascii + "|")
        }
        return lines.joined(separator: "\n")
    }
}
