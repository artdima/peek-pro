import SwiftUI

/// The four digits a person types into the app, with how long they last and a way to get new ones.
struct PairingCodeView: View {
    let code: PeekPairingCode
    var isLarge = true
    let onNew: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(code.spaced)
                .font(isLarge ? .system(size: 34, weight: .semibold, design: .rounded) : .title3.weight(.semibold))
                .monospacedDigit()
                .textSelection(.enabled)
                .accessibilityLabel("Pairing code \(code.digits)")
            HStack(spacing: 2) {
                CopyButton(text: code.digits)
                Button(action: onNew) {
                    Label("New Code", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("New code — the old one stops working")
            }
            Spacer(minLength: 0)
            countdown
        }
    }

    /// Runs down to 0:00; the code changes by itself when it gets there.
    private var countdown: some View {
        Text(timerInterval: code.issuedAt...code.expiresAt, countsDown: true)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .help("The code changes when this runs out")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        PairingCodeView(code: .random()) {}
        PairingCodeView(code: .random(), isLarge: false) {}
    }
    .padding()
    .frame(width: 320)
}
