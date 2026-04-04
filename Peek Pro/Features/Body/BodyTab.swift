import SwiftUI

/// The Request and Response tabs.
struct BodyTab: View {
    let entry: PeekEntry
    let side: PeekBodySide

    var body: some View {
        switch side {
        case .request:
            VStack(spacing: 0) {
                if !entry.request.queryItems.isEmpty {
                    QueryParametersSection(request: entry.request)
                        .padding(16)
                    Divider()
                }
                BodyViewer(payload: entry.request.body, baseName: "request-\(entry.id.value)",
                           loadKey: PeekBodyLoadKey(entryID: entry.id, side: .request))
            }
        case .response:
            if let response = entry.response {
                BodyViewer(payload: response.body, baseName: "response-\(entry.id.value)",
                           loadKey: PeekBodyLoadKey(entryID: entry.id, side: .response))
            } else if entry.state == .pending {
                ContentUnavailableView("Waiting for the Response", systemImage: "hourglass",
                                       description: Text("The request is still in flight."))
            } else {
                ContentUnavailableView("No Response", systemImage: "xmark.octagon",
                                       description: Text(entry.failure?.message ?? "The request failed before a response arrived."))
            }
        }
    }
}

#Preview("Response JSON") {
    BodyTab(entry: Fixtures.entry("f02"), side: .response)
        .frame(width: 900, height: 520)
}

#Preview("Request with Query — Dark") {
    BodyTab(entry: Fixtures.entry("f05"), side: .request)
        .frame(width: 900, height: 520)
        .preferredColorScheme(.dark)
}

#Preview("HTML") {
    BodyTab(entry: Fixtures.entry("f09"), side: .response)
        .frame(width: 900, height: 520)
}

#Preview("Image") {
    BodyTab(entry: Fixtures.entry("f04"), side: .response)
        .frame(width: 900, height: 520)
}

#Preview("Binary — Dark") {
    BodyTab(entry: Fixtures.entry("f21"), side: .response)
        .frame(width: 900, height: 520)
        .preferredColorScheme(.dark)
}

#Preview("Truncated") {
    BodyTab(entry: Fixtures.entry("f06"), side: .response)
        .frame(width: 900, height: 520)
}

#Preview("Remote") {
    BodyTab(entry: Fixtures.entry("f24"), side: .response)
        .environment(AppModel.preview(.live))
        .frame(width: 900, height: 520)
}

#Preview("Megabyte") {
    BodyTab(entry: Fixtures.entry("f05"), side: .response)
        .frame(width: 900, height: 520)
}
