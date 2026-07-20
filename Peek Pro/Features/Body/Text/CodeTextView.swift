import AppKit
import SwiftUI

enum CodeTextStyle {
    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    static func color(for kind: CodeToken.Kind) -> NSColor {
        switch kind {
        case .string: NSColor(named: "CodeString") ?? .systemRed
        case .number: NSColor(named: "CodeNumber") ?? .systemBlue
        case .keyword: NSColor(named: "CodeKeyword") ?? .systemPink
        case .comment: .secondaryLabelColor
        }
    }
}

/// Lets SwiftUI buttons reach the AppKit text view, e.g. to open its find bar.
final class CodeTextProxy {
    weak var textView: NSTextView?

    func showFind() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        textView.performTextFinderAction(item)
    }
}

/// Read-only monospaced text with line numbers and the system find bar; SwiftUI `Text` can't hold a megabyte.
struct CodeTextView: NSViewRepresentable {
    let text: String
    var syntax = CodeSyntax.plain
    var wraps = false
    var showsLineNumbers = true
    var fontSize = 12.0
    var proxy: CodeTextProxy?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView(usingTextLayoutManager: false)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isVerticallyResizable = true
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.layoutManager?.allowsNonContiguousLayout = true
        scrollView.documentView = textView

        context.coordinator.textView = textView
        if showsLineNumbers {
            let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
            scrollView.verticalRulerView = ruler
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            context.coordinator.ruler = ruler
        } else {
            textView.textContainerInset = NSSize(width: 12, height: 12)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let textView = coordinator.textView else { return }
        proxy?.textView = textView
        if coordinator.wraps != wraps {
            coordinator.wraps = wraps
            Self.apply(wraps: wraps, textView: textView, scrollView: scrollView)
        }
        if coordinator.text != text || coordinator.syntax != syntax || coordinator.fontSize != fontSize {
            coordinator.load(text, syntax: syntax, fontSize: fontSize)
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.highlightTask?.cancel()
    }

    private static func apply(wraps: Bool, textView: NSTextView, scrollView: NSScrollView) {
        guard let container = textView.textContainer else { return }
        if wraps {
            textView.isHorizontallyResizable = false
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.setFrameSize(NSSize(width: scrollView.contentSize.width, height: textView.frame.height))
            scrollView.hasHorizontalScroller = false
        } else {
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true
            scrollView.hasHorizontalScroller = true
        }
    }

    final class Coordinator {
        weak var textView: NSTextView?
        weak var ruler: LineNumberRulerView?
        var text: String?
        var syntax = CodeSyntax.plain
        var wraps: Bool?
        var fontSize = 12.0
        var highlightTask: Task<Void, Never>?

        /// Plain text goes in at once; colors follow when the background scan finishes.
        func load(_ text: String, syntax: CodeSyntax, fontSize: Double) {
            self.text = text
            self.syntax = syntax
            self.fontSize = fontSize
            highlightTask?.cancel()
            guard let textView, let storage = textView.textStorage else { return }
            let font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            storage.setAttributedString(NSAttributedString(string: text, attributes: attributes))
            ruler?.reload(text)
            textView.scroll(.zero)
            guard syntax != .plain else { return }
            highlightTask = Task { [weak self] in
                let tokens = await Task.detached(priority: .userInitiated) {
                    syntax.tokens(in: text)
                }.value
                guard !Task.isCancelled, let self, self.text == text, let storage = self.textView?.textStorage else { return }
                storage.beginEditing()
                for token in tokens {
                    storage.addAttribute(.foregroundColor, value: CodeTextStyle.color(for: token.kind), range: token.range)
                }
                storage.endEditing()
            }
        }
    }
}

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private var lineStarts: [Int] = [0]
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 36
        scrollView.contentView.postsBoundsChangedNotifications = true
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(contentDidChange(_:)),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(contentDidChange(_:)),
            name: NSView.frameDidChangeNotification, object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    func reload(_ text: String) {
        var starts = [0]
        for (offset, unit) in text.utf16.enumerated() where unit == 0x0A {
            starts.append(offset + 1)
        }
        lineStarts = starts
        let digits = max(3, String(starts.count).count)
        ruleThickness = CGFloat(digits) * 7 + 16
        needsDisplay = true
    }

    @objc private func contentDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()

        guard let textView, let scrollView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer,
              let length = textView.textStorage?.length
        else { return }

        let origin = textView.textContainerOrigin
        let visible = scrollView.contentView.bounds.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphs = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let characters = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let attributes: [NSAttributedString.Key: Any] = [.font: numberFont, .foregroundColor: NSColor.tertiaryLabelColor]

        var line = lineIndex(containing: characters.location)
        while line < lineStarts.count {
            let start = lineStarts[line]
            if start > NSMaxRange(characters) { break }
            let fragment: NSRect
            if start < length {
                fragment = layoutManager.lineFragmentRect(forGlyphAt: layoutManager.glyphIndexForCharacter(at: start), effectiveRange: nil)
            } else {
                fragment = layoutManager.extraLineFragmentRect
            }
            let y = convert(NSPoint(x: 0, y: fragment.minY + origin.y), from: textView).y
            let label = String(line + 1) as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: y + (fragment.height - size.height) / 2), withAttributes: attributes)
            line += 1
        }
    }

    private func lineIndex(containing location: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if lineStarts[middle] <= location {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return low
    }
}

#Preview("JSON") {
    CodeTextView(text: FixtureBodies.profile, syntax: .json)
        .frame(width: 700, height: 500)
}

#Preview("Megabyte — Dark") {
    CodeTextView(text: FixtureBodies.catalog, syntax: .json)
        .frame(width: 700, height: 500)
        .preferredColorScheme(.dark)
}
