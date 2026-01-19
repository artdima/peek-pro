import Foundation

enum MockScenario: String, CaseIterable, Identifiable {
    case waiting
    case portInUse
    case live
    case paused
    case large
    case disconnected
    case file
    case rejected

    var id: Self { self }

    var title: String {
        switch self {
        case .waiting: "Waiting for Devices"
        case .portInUse: "Port in Use"
        case .live: "Live Traffic"
        case .paused: "Recording Paused"
        case .large: "10 000 Requests"
        case .disconnected: "Device Disconnected"
        case .file: "Session Files"
        case .rejected: "Rejected Connections"
        }
    }
}
