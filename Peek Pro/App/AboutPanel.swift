import AppKit

enum AboutPanel {
    static let peekRepository = URL(string: "https://github.com/artdima/peek")!

    static func show() {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate()
    }

    private static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 4
        let body: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let text = NSMutableAttributedString(
            string: "Network calls recorded by Peek — live from a device or from a .peek file.\nInspired by Pulse Pro.\n",
            attributes: body
        )
        var link = body
        link[.link] = peekRepository
        text.append(NSAttributedString(string: "github.com/artdima/peek", attributes: link))
        return text
    }
}
