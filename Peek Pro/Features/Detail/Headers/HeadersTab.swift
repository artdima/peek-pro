import SwiftUI

struct HeadersTab: View {
    let entry: PeekEntry

    @State private var filter = ""
    @AppStorage("headers.sortedByName") private var isSortedByName = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(.secondary)
                    TextField("Filter", text: $filter, prompt: Text("Filter by name or value"))
                        .textFieldStyle(.plain)
                    if !filter.isEmpty {
                        Button {
                            filter = ""
                        } label: {
                            Label("Clear", systemImage: "xmark.circle.fill")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 280)

                Toggle("Sort by Name", isOn: $isSortedByName)
                    .toggleStyle(.checkbox)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    KeyValueSection(title: "Request Headers", pairs: pairs(entry.request.headers), emptyText: emptyText)
                    if let response = entry.response {
                        KeyValueSection(title: "Response Headers", pairs: pairs(response.headers), emptyText: emptyText)
                    } else {
                        Text(entry.state == .pending ? "Waiting for the response…" : "No response")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptyText: String {
        filter.isEmpty ? "No headers" : "No headers match “\(filter)”"
    }

    private func pairs(_ headers: PeekHeaders) -> [KeyValuePair] {
        var list = KeyValuePair.list(headers.entries)
        let query = filter.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.value.localizedCaseInsensitiveContains(query) }
        }
        if isSortedByName {
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return list
    }
}

/// Decoded query items; the Request tab shows it above the body.
struct QueryParametersSection: View {
    let request: PeekRequest

    var body: some View {
        KeyValueSection(
            title: "Query Parameters",
            pairs: KeyValuePair.list(request.queryItems.map { (name: $0.name, value: $0.value ?? "") }),
            emptyText: "No query parameters"
        )
    }
}

#Preview("Login") {
    HeadersTab(entry: Fixtures.entry("f01"))
        .frame(width: 900, height: 600)
}

#Preview("Pending — Dark") {
    HeadersTab(entry: Fixtures.entry("f17"))
        .frame(width: 900, height: 400)
        .preferredColorScheme(.dark)
}

#Preview("Query") {
    QueryParametersSection(request: Fixtures.entry("f25").request)
        .padding()
        .frame(width: 900)
}
