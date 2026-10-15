import AppKit
import SwiftUI

/// Settings as a sidebar of pages, the way System Settings lays them out.
struct SettingsView: View {
    @AppStorage(SettingsKey.settingsPage) private var selectedPage = SettingsPage.general.rawValue
    @State private var history = SettingsHistory(start: .general)
    @State private var query = ""
    @Environment(\.colorScheme) private var colorScheme

    private var page: SettingsPage { SettingsPage.stored(selectedPage) }

    private var selection: Binding<SettingsPage?> {
        Binding(
            get: { page },
            set: { if let page = $0 { selectedPage = page.rawValue } }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(SettingsGroup.allCases) { group in
                    let pages = group.pages.filter { $0.matches(query) }
                    if !pages.isEmpty {
                        Section(group.title) {
                            ForEach(pages) { page in
                                Label {
                                    Text(page.title)
                                } icon: {
                                    SettingsIcon(page: page)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $query, placement: .sidebar, prompt: "Search")
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            Group {
                switch page {
                case .general: GeneralSettings()
                case .appearance: AppearanceSettings()
                case .server: ServerSettings()
                case .pairing: PairingSettings()
                case .devices: DevicesSettings()
                case .help: HelpSettings()
                }
            }
            .formStyle(.grouped)
            .navigationTitle(page.title)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        history.goBack()
                        selectedPage = history.current.rawValue
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled(!history.canGoBack)
                    Button {
                        history.goForward()
                        selectedPage = history.current.rawValue
                    } label: {
                        Label("Forward", systemImage: "chevron.right")
                    }
                    .disabled(!history.canGoForward)
                }
            }
        }
        .id(colorScheme)
        .background(UnifiedToolbarStyle())
        .frame(minWidth: 720, idealWidth: 820, maxWidth: .infinity, minHeight: 480, idealHeight: 580, maxHeight: .infinity)
        .onAppear { history = SettingsHistory(start: page) }
        // A step back lands on the page the history already holds, so this records only new pages.
        .onChange(of: selectedPage) { history.visit(page) }
    }
}

/// The Settings scene gives its window a preferences toolbar, which centres the title over the buttons.
private struct UnifiedToolbarStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ToolbarStyleView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ToolbarStyleView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.toolbarStyle = .unified
        }
    }
}

/// The sidebar's glyph: a symbol on a rounded tile in the page's colour.
struct SettingsIcon: View {
    let page: SettingsPage

    var body: some View {
        Image(systemName: page.symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(page.color.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Opens Settings on one page, from wherever in the app the page is wanted.
struct SettingsPageLink<Label: View>: View {
    let page: SettingsPage
    @ViewBuilder let label: () -> Label

    @Environment(\.openSettings) private var openSettings
    @AppStorage(SettingsKey.settingsPage) private var selectedPage = SettingsPage.general.rawValue

    var body: some View {
        Button {
            selectedPage = page.rawValue
            openSettings()
        } label: {
            label()
        }
    }
}

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model

    @AppStorage(DetailPlacement.storageKey) private var detailPlacement: DetailPlacement = .bottom
    @AppStorage(DetailPlacement.lastVisibleStorageKey) private var lastVisiblePlacement: DetailPlacement = .bottom

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                DetailPlacementPicker(selection: openingPlacement)
                    .accessibilityLabel("Details")
            } header: {
                Text("Console")
            } footer: {
                Text("Where a request's details open — below the list or beside it.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Show requests as", selection: $model.viewMode) {
                    ForEach([ConsoleViewMode.list, .table]) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Requests")
            } footer: {
                Text("A table has a column for each field; a list reads like Peek on the phone.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// With the details hidden, a choice here is where they come back.
    private var openingPlacement: Binding<DetailPlacement> {
        Binding {
            if detailPlacement != .hidden { return detailPlacement }
            return lastVisiblePlacement == .hidden ? .bottom : lastVisiblePlacement
        } set: { placement in
            if detailPlacement == .hidden {
                lastVisiblePlacement = placement
            } else {
                detailPlacement = placement
            }
        }
    }
}

private struct AppearanceSettings: View {
    @AppStorage(SettingsKey.appTheme) private var theme: AppTheme = .system
    @AppStorage(SettingsKey.bodyFontSize) private var fontSize = 12.0
    @AppStorage(SettingsKey.jsonMode) private var jsonMode: JSONViewMode = .raw
    @AppStorage(SettingsKey.wraps) private var wraps = false

    var body: some View {
        Form {
            Section {
                AppThemePicker(selection: $theme)
                    .accessibilityLabel("App Theme")
            } header: {
                Text("App Theme")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Font size")
                        Spacer(minLength: 16)
                        Text("A")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Slider(value: wholeFontSize, in: 10...18)
                            .labelsHidden()
                            .frame(width: 160)
                            .accessibilityLabel("Font size")
                        Text("A")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                            .padding(.leading, 10)
                    }
                    BodyPreview(fontSize: fontSize, wraps: wraps)
                }
                Picker("Open JSON as", selection: $jsonMode) {
                    ForEach(JSONViewMode.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Wrap long lines", isOn: $wraps)
            } header: {
                Text("Bodies")
            } footer: {
                Text("How request and response bodies read in the Request and Response tabs.")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: theme) { theme.apply() }
    }

    private var wholeFontSize: Binding<Double> {
        Binding(get: { fontSize }, set: { fontSize = $0.rounded() })
    }
}

private struct BodyPreview: View {
    let fontSize: Double
    let wraps: Bool

    private static let sample = """
        {
          "name": "Trail Runner",
          "price": 129.00,
          "tags": ["running", "trail", "lightweight", "waterproof"]
        }
        """

    var body: some View {
        Group {
            if wraps {
                text
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    text.fixedSize()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .settingsWell(cornerRadius: 8)
    }

    private var text: some View {
        Text(highlighted)
            .font(.system(size: fontSize, design: .monospaced))
            .lineSpacing(2)
    }

    private var highlighted: AttributedString {
        var result = AttributedString(Self.sample)
        for token in JSONHighlighter.tokens(in: Self.sample) {
            guard let range = Range(token.range, in: result) else { continue }
            result[range].foregroundColor = Color(nsColor: CodeTextStyle.color(for: token.kind))
        }
        return result
    }
}

private struct ServerSettings: View {
    @Environment(AppModel.self) private var model

    @AppStorage(SettingsKey.port) private var port = SettingsKey.defaultPort
    @AppStorage(SettingsKey.bonjourEnabled) private var bonjourEnabled = true
    @AppStorage(SettingsKey.bonjourName) private var bonjourName = ""

    private var server: PeekServerState { model.store.server }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Port")
                        Text("Devices connect to this port")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(server.status == .listening ? Color(.statusSuccess) : .orange)
                            .frame(width: 7, height: 7)
                        Text(server.status == .listening ? "Listening" : "Port is in use")
                            .foregroundStyle(.secondary)
                    }
                    TextField("Port", value: $port, format: .number.grouping(.never))
                        .labelsHidden()
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .frame(width: 70, height: 24)
                        .settingsWell()
                        .onSubmit {
                            port = min(max(port, 1_024), 65_535)
                            model.applyServerSettings()
                        }
                }
                .padding(.vertical, 2)
                LabeledContent(server.addresses.count > 1 ? "Addresses" : "Address") {
                    VStack(alignment: .trailing, spacing: 6) {
                        if server.addresses.isEmpty {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(server.addresses, id: \.self) { address in
                            CopyableField(value: "\(address):\(String(server.port))")
                        }
                    }
                }
            } header: {
                Text("Server")
            } footer: {
                Text("Changing the port disconnects devices until they use the new one.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Advertise on the local network", isOn: $bonjourEnabled)
                    .onChange(of: bonjourEnabled) { model.applyServerSettings() }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Name")
                        if let name = server.bonjourName {
                            Text("Advertised as \(name)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 12)
                    TextField("Name", text: $bonjourName, prompt: Text(PeekServerState.defaultBonjourName))
                        .labelsHidden()
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .frame(width: 160, height: 24)
                        .settingsWell()
                        .disabled(!bonjourEnabled)
                        .onSubmit { model.applyServerSettings() }
                }
                .padding(.vertical, 2)
            } header: {
                Text("Bonjour")
            } footer: {
                Text("Lets devices on the same Wi-Fi find this Mac without typing an address. Many office networks block it — the address above always works.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PairingSettings: View {
    @Environment(AppModel.self) private var model

    @AppStorage(SettingsKey.tokenPolicy) private var tokenPolicy: TokenPolicy = .perLaunch

    private var server: PeekServerState { model.store.server }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Code")
                        Text("Expires in \(server.pairingCode.expiresAt, style: .timer)")
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Text(server.pairingCode.digits)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .textSelection(.enabled)
                        .accessibilityLabel("Pairing code \(server.pairingCode.digits)")
                    HStack(spacing: 6) {
                        CopyButton(text: server.pairingCode.digits, isBordered: true)
                        Button { model.newPairingCode() } label: {
                            Label("New Code", systemImage: "arrow.clockwise")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .help("New code — the old one stops working")
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .padding(.leading, 4)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Pairing Code")
            } footer: {
                Text("A person types the code into the app once — Peek → Connect to Peek Pro — and the device is remembered. The code lasts a few minutes and changes after five wrong tries.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Policy", selection: $tokenPolicy) {
                    ForEach(TokenPolicy.allCases) { Text($0.title).tag($0) }
                }
                .onChange(of: tokenPolicy) { model.store.applyTokenPolicy() }
                LabeledContent("Current") {
                    HStack(spacing: 12) {
                        CopyableField(value: server.token)
                        Button("Regenerate") { model.store.regenerateToken() }
                    }
                }
            } header: {
                Text("Token")
            } footer: {
                Text("For apps that have the token written in code, such as in CI, where nobody types. A new token refuses apps that still use the old one.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CopyableField: View {
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(value)
                .monospaced()
                .textSelection(.enabled)
                .padding(.horizontal, 10)
            Divider()
            CopyButton(text: value)
                .padding(.horizontal, 6)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 24)
        .settingsWell()
    }
}

private extension View {
    func settingsWell(cornerRadius: CGFloat = 6) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(Color(nsColor: .textBackgroundColor), in: shape)
            .overlay { shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5) }
    }
}

private struct DevicesSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
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
        }
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

private struct HelpSettings: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    var body: some View {
        Form {
            Section {
                Link("Connecting an App", destination: PeekProLinks.remoteGuide)
                Link("Peek Pro on GitHub", destination: PeekProLinks.repository)
                Link("Report an Issue…", destination: PeekProLinks.issues)
                Link("Peek on GitHub", destination: PeekProLinks.peek)
            } header: {
                Text("Links")
            } footer: {
                Text("The guide covers adding peek_remote, pairing, addresses for each kind of device and what to do when a device can't connect.")
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: version)
                LabeledContent("License", value: "MIT")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel.preview(.live))
}
