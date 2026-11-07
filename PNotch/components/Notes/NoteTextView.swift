import AppKit
import SwiftUI

/// Plain text to write in, transparent, that takes the keyboard on a click though the notch never
/// activates PNotch. Give each note its own (`.id`), so undo stays with the note.
struct NoteTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 13
    var lineSpacing: CGFloat = 3
    var insertionColor: Color = Palette.ink
    /// Changing it puts the cursor in the text, at its end.
    var focusRequest = 0
    /// Puts the cursor in the text as soon as it shows, e.g. for a new note.
    var focusesOnAppear = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        // Sized the classic way: as wide as the scroll view, as tall as its text.
        let size = scrollView.contentSize
        let textView = NoteNSTextView(frame: NSRect(origin: .zero, size: size))
        textView.minSize = NSSize(width: 0, height: size.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: size.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = .zero

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        let font = NSFont.systemFont(ofSize: fontSize)
        let color = NSColor.white.withAlphaComponent(0.9)
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = font
        textView.textColor = color
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        textView.insertionPointColor = NSColor(insertionColor)
        textView.string = text
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.focusRequest = focusRequest
        if focusesOnAppear {
            focus(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        if context.coordinator.focusRequest != focusRequest {
            context.coordinator.focusRequest = focusRequest
            focus(textView)
        }
    }

    private func focus(_ textView: NSTextView) {
        // After this update: the window may only now be taking the keyboard.
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextView
        var focusRequest = 0

        init(_ parent: NoteTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// Asks the panel for the keyboard when clicked.
final class NoteNSTextView: NSTextView {
    override var needsPanelToBecomeKey: Bool {
        true
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}
