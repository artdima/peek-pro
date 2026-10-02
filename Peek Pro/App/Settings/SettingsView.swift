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
                        model.applyServerSettings()
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
                LabeledContent("Pairing code") {
                    PairingCodeView(code: server.pairingCode, isLarge: false) { model.newPairingCode() }
                        .frame(maxWidth: 260)
                }
                Picker("Token", selection: $tokenPolicy) {
                    ForEach(TokenPolicy.allCases) { Text($0.title).tag($0) }
                }
                .onChange(of: tokenPolicy) { model.store.applyTokenPolicy() }
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
                Text("A person types the code into the app once; the token is for apps that have it written in code, such as in CI. A new token refuses apps that still use the old one.")
                    .foregroundStyle(.secondary)
            }

            Section {
                if model.store.pairedDevices.isEmpty {
                    Text("No devices have paired yet. A device that connects with the code shows up here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.store.pairedDevices.reversed()) { device in
                        PairedDeviceRow(device: device) { model.forgetDevice(device.id) }
                    }
                    Button("Forget All", role: .destructive) { model.forgetAllDevices() }
                }
            } header: {
                Text("Paired Devices")
            } footer: {
                Text("A forgotten device is disconnected and has to enter the code again.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Advertise on the local network", isOn: $bonjourEnabled)
                    .onChange(of: bonjourEnabled) { model.applyServerSettings() }
                TextField("Name", text: $bonjourName, prompt: Text(PeekServerState.defaultBonjourName))
                    .disabled(!bonjourEnabled)
                    .onSubmit { model.applyServerSettings() }
                if let name = server.bonjourName {
                    LabeledContent("Advertised as", value: name)
                }
            } header: {
                Text("Bonjour")
            } footer: {
                Text("Lets devices on the same Wi-Fi find this Mac without typing an address. Many office networks block it — the address above always works.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Link("Connecting an App", destination: PeekProLinks.remoteGuide)
                Link("Peek Pro on GitHub", destination: PeekProLinks.repository)
            } footer: {
                Text("The guide covers adding peek_remote, pairing, addresses for each kind of device and what to do when a device can't connect.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PairedDeviceRow: View {
    let device: PeekPairedDevice
    let onForget: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.platform.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.title)
                Text("\(device.platform.title) · \(device.address) · last seen \(PeekFormat.relative(device.lastSeenAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Forget", action: onForget)
                .controlSize(.small)
        }
        .help("Paired \(PeekFormat.dateTime(device.pairedAt))")
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
