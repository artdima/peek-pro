import SwiftUI

extension PeekStatusClass {
    var color: Color {
        switch self {
        case .success: Color(.statusSuccess)
        case .redirect: Color(.statusRedirect)
        case .clientError: Color(.statusClientError)
        case .serverError: Color(.statusServerError)
        case .informational, .unknown: Color(.statusNeutral)
        }
    }

    var title: String {
        switch self {
        case .informational: "1xx"
        case .success: "2xx"
        case .redirect: "3xx"
        case .clientError: "4xx"
        case .serverError: "5xx"
        case .unknown: "Other"
        }
    }
}

extension PeekFailureKind {
    var title: String {
        switch self {
        case .timeout: "Timed out"
        case .connection: "Connection failed"
        case .badCertificate: "Certificate rejected"
        case .cancelled: "Cancelled"
        case .badResponse: "Unexpected response"
        case .unknown: "Failed"
        }
    }
}

extension PeekBodyUnavailableReason {
    var title: String {
        switch self {
        case .streamed: "Body was streamed and not kept"
        case .tooLarge: "Body was too large to keep"
        case .notCaptured: "Body was not captured"
        case .unreadable: "Body could not be read"
        }
    }
}

extension PeekEntryState {
    var title: String {
        switch self {
        case .pending: "Pending"
        case .completed: "Completed"
        case .failed: "Failed"
        }
    }
}

extension PeekEntry {
    var tint: Color {
        if let failure {
            return failure.kind == .cancelled ? Color(.statusNeutral) : Color(.statusFailure)
        }
        return statusClass?.color ?? Color(.statusNeutral)
    }

    /// "200 OK", "Timed out" or "Pending" — the way Pulse labels a call.
    var statusTitle: String {
        if let response {
            let phrase = response.statusMessage ?? PeekHTTPStatus.reasonPhrase(for: response.statusCode)
            return [String(response.statusCode), phrase].compactMap(\.self).joined(separator: " ")
        }
        return failure?.kind.title ?? PeekEntryState.pending.title
    }

    var statusSymbol: String {
        switch state {
        case .pending: "clock.fill"
        case .failed: failure?.kind == .cancelled ? "xmark.circle.fill" : "exclamationmark.circle.fill"
        case .completed: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
        }
    }
}

extension PeekTimings.Phase {
    var title: String {
        switch self {
        case .blocked: "Queued"
        case .dns: "DNS"
        case .connect: "Connect"
        case .ssl: "Secure"
        case .send: "Request"
        case .wait: "Waiting"
        case .receive: "Download"
        }
    }

    var color: Color {
        switch self {
        case .blocked: .gray
        case .dns: .purple
        case .connect: .yellow
        case .ssl: .red
        case .send: .green
        case .wait: .secondary
        case .receive: .blue
        }
    }
}

extension PeekPlatform {
    var title: String {
        switch self {
        case .iOS: "iOS"
        case .android: "Android"
        case .macOS: "macOS"
        case .windows: "Windows"
        case .linux: "Linux"
        case .web: "Web"
        }
    }
}

extension PeekDevice {
    var symbolName: String {
        switch platform {
        case .iOS: model?.hasPrefix("iPad") == true ? "ipad" : "iphone"
        case .android: "candybarphone"
        case .macOS: "laptopcomputer"
        case .windows: "pc"
        case .linux: "desktopcomputer"
        case .web: "globe"
        }
    }

    /// "iOS 26.0", "Android 16"; web reports the host OS instead.
    var systemTitle: String {
        platform == .web ? osVersion : "\(platform.title) \(osVersion)"
    }
}
