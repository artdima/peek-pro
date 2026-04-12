import SwiftUI

struct ErrorTab: View {
    let entry: PeekEntry
    let showTab: (DetailTab) -> Void

    var body: some View {
        if let failure = entry.failure {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ErrorHeader(failure: failure)
                    if failure.kind == .badResponse, let response = entry.response {
                        BadResponseNotice(response: response) { showTab(.response) }
                    }
                    ErrorTextSection(title: "Message", text: failure.message)
                    if let details = failure.details {
                        ErrorTextSection(title: "Details", text: details)
                    }
                    if let stackTrace = failure.stackTrace {
                        StackTraceSection(stackTrace: stackTrace)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("No Error", systemImage: "checkmark.circle",
                                   description: Text("This request didn't fail."))
        }
    }
}

private struct ErrorHeader: View {
    let failure: PeekFailure

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30))
                .foregroundStyle(failure.kind == .cancelled ? Color(.statusNeutral) : Color(.statusFailure))
            VStack(alignment: .leading, spacing: 3) {
                Text(failure.kind.title)
                    .font(.title2.weight(.semibold))
                Text(explanation)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var symbol: String {
        switch failure.kind {
        case .timeout: "clock.badge.exclamationmark"
        case .connection: "wifi.exclamationmark"
        case .badCertificate: "lock.trianglebadge.exclamationmark"
        case .cancelled: "xmark.circle"
        case .badResponse: "exclamationmark.bubble"
        case .unknown: "exclamationmark.octagon"
        }
    }

    private var explanation: String {
        switch failure.kind {
        case .timeout: "The server didn't answer in time, or the connection took too long to open."
        case .connection: "The app couldn't reach the server — no network, a wrong host or a refused connection."
        case .badCertificate: "The server's certificate wasn't trusted, so the app refused to talk to it."
        case .cancelled: "The app cancelled the request itself — usually on purpose, e.g. a newer request replaced it."
        case .badResponse: "A response came back, but the client treated its status as an error."
        case .unknown: "The client reported an error Peek couldn't classify."
        }
    }
}

private struct BadResponseNotice: View {
    let response: PeekResponse
    let showResponse: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.doc")
                .foregroundStyle(.secondary)
            Text("The server answered \(response.statusCode) \(response.statusMessage ?? PeekHTTPStatus.reasonPhrase(for: response.statusCode) ?? "").")
            Spacer()
            Button("Show Response", action: showResponse)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ErrorTextSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                CopyButton(text: text, title: "Copy \(title)")
            }
            Text(text)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// Frames as a list: app frames stand out, `<asynchronous suspension>` markers fade.
private struct StackTraceSection: View {
    let stackTrace: String

    private var lines: [String] {
        stackTrace.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Stack Trace")
                    .font(.headline)
                Text(lines.filter { $0.hasPrefix("#") }.count, format: .number)
                    .foregroundStyle(.tertiary)
                Spacer()
                CopyButton(text: stackTrace, title: "Copy Stack Trace")
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .foregroundStyle(style(for: line))
                        .fontWeight(isAppFrame(line) ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(line)
                }
            }
            .font(.callout.monospaced())
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Frames outside Dart and the network packages are the app's own — usually where to look first.
    private func isAppFrame(_ line: String) -> Bool {
        guard line.contains("package:") else { return false }
        return !["package:dio/", "package:http/", "package:chopper/", "package:talker"].contains { line.contains($0) }
    }

    private func style(for line: String) -> HierarchicalShapeStyle {
        if line.hasPrefix("<") { return .tertiary }
        return isAppFrame(line) ? .primary : .secondary
    }
}

#Preview("Timeout") {
    ErrorTab(entry: Fixtures.entry("f12")) { _ in }
        .frame(width: 900, height: 620)
}

#Preview("Bad Response — Dark") {
    ErrorTab(entry: Fixtures.entry("f16")) { _ in }
        .frame(width: 900, height: 420)
        .preferredColorScheme(.dark)
}

#Preview("Certificate") {
    ErrorTab(entry: Fixtures.entry("f14")) { _ in }
        .frame(width: 900, height: 360)
}
