import SwiftUI

struct FiltersPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let facets = PeekFacets(model.selectedEntries)
        let filter = model.filter

        List {
            Section {
                HStack {
                    Text(summary)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset") { model.resetFilters() }
                        .disabled(!model.hasFilters)
                }
                .font(.callout)
            }

            if !facets.statusClasses.isEmpty || !filter.statusClasses.isEmpty {
                Section("Status") {
                    ForEach(merged(facets.statusClasses, filter.statusClasses)) { facet in
                        FacetToggle(title: facet.value.title, count: facet.count, tint: facet.value.color,
                                    isOn: $model.filter.statusClasses[contains: facet.value])
                    }
                    DisclosureGroup("Codes") {
                        ForEach(merged(facets.statusCodes, filter.statusCodes)) { facet in
                            FacetToggle(title: codeTitle(facet.value), count: facet.count,
                                        tint: PeekStatusClass(statusCode: facet.value).color,
                                        isOn: $model.filter.statusCodes[contains: facet.value])
                        }
                    }
                }
            }

            if !facets.states.isEmpty || !filter.states.isEmpty {
                Section("State") {
                    ForEach(merged(facets.states, filter.states)) { facet in
                        FacetToggle(title: facet.value.title, count: facet.count,
                                    isOn: $model.filter.states[contains: facet.value])
                    }
                }
            }

            stringSection("Method", facets.methods, $model.filter.methods)
            stringSection("Host", facets.hosts, $model.filter.hosts)
            stringSection("Content Type", facets.contentTypes, $model.filter.contentTypes)
            stringSection("Source", facets.sources, $model.filter.sources)

            Section("Duration") {
                HStack(spacing: 6) {
                    TextField("Min", value: $model.filter.duration.minMilliseconds, format: .number, prompt: Text("Min"))
                    Text("–")
                        .foregroundStyle(.secondary)
                    TextField("Max", value: $model.filter.duration.maxMilliseconds, format: .number, prompt: Text("Max"))
                    Text("ms")
                        .foregroundStyle(.secondary)
                }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            }

            Section("Time") {
                Picker("Time", selection: $model.timeWindow) {
                    ForEach(ConsoleTimeWindow.allCases) { window in
                        Text(window.title).tag(window)
                    }
                }
                .labelsHidden()
                .help("Counted back from the latest request")
            }

            Section("Other") {
                Toggle("Only Pinned", isOn: $model.filter.onlyPinned)
                    .toggleStyle(.checkbox)
            }
        }
        .listStyle(.sidebar)
    }

    private var summary: String {
        let total = model.selectedEntries.count
        let shown = model.visibleEntries.count
        return shown == total ? "\(total) requests" : "\(shown) of \(total) requests"
    }

    @ViewBuilder
    private func stringSection(_ title: String, _ values: [PeekFacet<String>], _ selection: Binding<Set<String>>) -> some View {
        let all = merged(values, selection.wrappedValue)
        if !all.isEmpty {
            Section(title) {
                ForEach(all) { facet in
                    FacetToggle(title: facet.value, count: facet.count, isOn: selection[contains: facet.value])
                }
            }
        }
    }

    /// Keeps a checked value visible after the session stops having it, so it can still be unchecked.
    private func merged<Value: Hashable & Sendable>(_ facets: [PeekFacet<Value>], _ selected: Set<Value>) -> [PeekFacet<Value>] {
        let present = Set(facets.map(\.value))
        return facets + selected.subtracting(present).map { PeekFacet(value: $0, count: 0) }
    }

    private func codeTitle(_ code: Int) -> String {
        [String(code), PeekHTTPStatus.reasonPhrase(for: code)].compactMap(\.self).joined(separator: " ")
    }
}

private extension PeekDurationRange {
    var minMilliseconds: Double? {
        get { min.map { $0.timeInterval * 1_000 } }
        set { min = newValue.map { .milliseconds($0) } }
    }

    var maxMilliseconds: Double? {
        get { max.map { $0.timeInterval * 1_000 } }
        set { max = newValue.map { .milliseconds($0) } }
    }
}

private struct FacetToggle: View {
    let title: String
    let count: Int
    var tint: Color?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 6) {
                if let tint {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                }
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 6)
                Text(count, format: .number)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
    }
}

#Preview("Live") {
    FiltersPanel()
        .environment(AppModel.preview(.live))
        .frame(width: 270, height: 900)
}

#Preview("Active — Dark") {
    let model = AppModel.preview(.live)
    model.filter.statusClasses = [.clientError, .serverError]
    model.filter.methods = ["GET"]
    model.filter.duration = PeekDurationRange(min: .milliseconds(100))
    return FiltersPanel()
        .environment(model)
        .frame(width: 270, height: 900)
        .preferredColorScheme(.dark)
}
