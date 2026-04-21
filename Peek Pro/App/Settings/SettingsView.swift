import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Connection", systemImage: "antenna.radiowaves.left.and.right") {
                ConnectionSettings()
            }
            Tab("Appearance", systemImage: "paintbrush") {
                AppearanceSettings()
            }
        }
        .frame(width: 540)
        .scenePadding()
    }
}

private struct ConnectionSettings: View {
    @Environment(AppModel.self) private var model

    @AppStorage(SettingsKey.port) private var port = SettingsKey.defaultPort
    @AppStorage(SettingsKey.tokenPolicy) private var tokenPolicy: TokenPolicy = .perLaunch
    @AppStorage(SettingsKey.bonjourEnabled) private var bonjourEnabled = true
    @AppStorage(SettingsKey.bonjourName) private var bonjourName = ""

    private var server: PeekServerState { model.store.server }

    var body: some View {
        Form {
            Section {
                TextField("Port", value: $port, format: .number.grouping(.never))
                    .onSubmit {
                        port = min(max(port, 1_024), 65_535)
                        model.store.applyServerSettings()
                    }
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(server.status == .listening ? Color(.statusSuccess) : .orange)
                            .frame(width: 7, height: 7)
                        Text(server.status == .listening ? "Listening" : "Port is in use")
                    }
                }
                LabeledContent("Addresses") {
                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(server.addresses, id: \.self) { address in
                            Text("\(address):\(String(server.port))")
                                .monospaced()
                                .textSelection(.enabled)
                        }
                    }
                }
            } header: {
                Text("Server")
            } footer: {
                Text("Devices connect to this port. Changing it disconnects them until they use the new one.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Token", selection: $tokenPolicy) {
                    ForEach(TokenPolicy.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Current") {
                    HStack(spacing: 6) {
                        Text(server.token)
                            .monospaced()
                            .textSelection(.enabled)
                        CopyButton(text: server.token)
                        Button("Regenerate") { model.store.regenerateToken() }
                    }
                }
            } header: {
                Text("Access")
            } footer: {
                Text("A device must send this token to connect. A new token refuses devices that still use the old one.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Advertise on the local network", isOn: $bonjourEnabled)
                    .onChange(of: bonjourEnabled) { model.store.applyServerSettings() }
                TextField("Name", text: $bonjourName, prompt: Text(FixtureSessions.server.bonjourName ?? "Peek Pro"))
                    .disabled(!bonjourEnabled)
                    .onSubmit { model.store.applyServerSettings() }
            } header: {
                Text("Bonjour")
            } footer: {
                Text("Lets devices on the same Wi-Fi find this Mac without typing an address. Many office networks block it — the address above always works.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppearanceSettings: View {
    @Environment(AppModel.self) private var model

    @AppStorage(SettingsKey.bodyFontSize) private var fontSize = 12.0
    @AppStorage(SettingsKey.jsonMode) private var jsonMode: JSONViewMode = .raw
    @AppStorage(SettingsKey.wraps) private var wraps = false
    @AppStorage(DetailPlacement.storageKey) private var detailPlacement: DetailPlacement = .bottom

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Requests") {
                Picker("Show as", selection: $model.viewMode) {
                    ForEach(ConsoleViewMode.allCases) { Text($0.title).tag($0) }
                }
                Picker("Details", selection: $detailPlacement) {
                    ForEach(DetailPlacement.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Bodies") {
                LabeledContent("Font size") {
                    HStack {
                        Slider(value: $fontSize, in: 10...18, step: 1)
                            .frame(width: 180)
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                Text("\"name\": \"Trail Runner\", \"price\": 129.00")
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.secondary)
                Picker("Open JSON as", selection: $jsonMode) {
                    ForEach(JSONViewMode.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Wrap long lines", isOn: $wraps)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
        .environment(AppModel.preview(.live))
}
