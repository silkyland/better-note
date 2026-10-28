import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    let note: Note
    let controller: EditorController
    let onChange: (String, Data?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        let textView = controller.textView ?? NSTextView()
        textView.removeFromSuperview()
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        textView.setAccessibilityLabel("Note body")
        scroll.documentView = textView
        controller.textView = textView
        if controller.loadedNoteID != note.id {
            context.coordinator.load(note, into: textView)
        } else {
            context.coordinator.noteID = note.id
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scroll.documentView as? NSTextView else { return }
        controller.textView = textView
        textView.isEditable = !note.isTrashed
        if context.coordinator.noteID != note.id { context.coordinator.load(note, into: textView) }
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var noteID: UUID?
        private var isLoading = false
        init(_ parent: RichTextEditor) { self.parent = parent }

        func load(_ note: Note, into view: NSTextView) {
            isLoading = true
            noteID = note.id
            parent.controller.loadedNoteID = note.id
            view.undoManager?.removeAllActions()
            if let rtf = note.richText {
                do {
                    let attributed = try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
                    view.textStorage?.setAttributedString(attributed)
                } catch {
                    view.textStorage?.setAttributedString(MarkdownRendering.render(note.text))
                }
            } else { view.textStorage?.setAttributedString(MarkdownRendering.render(note.text)) }
            view.typingAttributes = NoteStyle.bodyAttributes
            view.setSelectedRange(NSRange(location: 0, length: 0))
            view.scrollToBeginningOfDocument(nil)
            isLoading = false
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
            guard !isLoading, let replacement = replacementString else { return true }
            if replacement == " " { return !EditorTyping.handleSpace(in: textView, range: range) }
            if replacement.count == 1, "*_`~)".contains(replacement) {
                return !EditorTyping.handleInlineCloser(replacement, in: textView, range: range)
            }
            return true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !isLoading else { return false }
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)): return EditorTyping.handleNewline(in: textView)
            case #selector(NSResponder.deleteBackward(_:)): return EditorTyping.handleBackspace(in: textView)
            case #selector(NSResponder.insertTab(_:)): return EditorTyping.handleTab(in: textView)
            default: return false
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isLoading, let view = notification.object as? NSTextView, let storage = view.textStorage else { return }
            do {
                let rtf = try storage.data(from: NSRange(location: 0, length: storage.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                parent.onChange(view.string, rtf)
            } catch {
                // Plain text remains recoverable even if an imported attribute cannot be encoded as RTF.
                parent.onChange(view.string, nil)
            }
        }
    }
}
