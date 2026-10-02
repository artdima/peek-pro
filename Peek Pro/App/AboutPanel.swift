import AppKit

enum AboutPanel {
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
        link[.link] = PeekProLinks.repository
        text.append(NSAttributedString(string: "github.com/artdima/peek-pro", attributes: link))
        return text
    }
}
