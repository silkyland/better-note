import AppKit
import Observation

@MainActor @Observable
final class EditorController {
    var textView: NSTextView?
    var loadedNoteID: UUID?
    var fontSize: CGFloat = 17

    func bold() { applyFontTrait(.boldFontMask) }
    func italic() { applyFontTrait(.italicFontMask) }

    private func applyFontTrait(_ trait: NSFontTraitMask) {
        guard let view = textView, view.isEditable else { return }
        view.window?.makeFirstResponder(view)
        let range = view.selectedRange()
        if range.length == 0 {
            let font = view.typingAttributes[.font] as? NSFont ?? .systemFont(ofSize: fontSize)
            let hasTrait = NSFontManager.shared.traits(of: font).contains(trait)
            view.typingAttributes[.font] = hasTrait ? NSFontManager.shared.convert(font, toNotHaveTrait: trait) : NSFontManager.shared.convert(font, toHaveTrait: trait)
            return
        }
        mutateSelection { storage, range in
            let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? .systemFont(ofSize: self.fontSize)
            let removing = NSFontManager.shared.traits(of: font).contains(trait)
            storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let current = value as? NSFont ?? .systemFont(ofSize: self.fontSize)
                let converted = removing ? NSFontManager.shared.convert(current, toNotHaveTrait: trait) : NSFontManager.shared.convert(current, toHaveTrait: trait)
                storage.addAttribute(.font, value: converted, range: subrange)
            }
        }
    }

    /// Toggles the current paragraph(s) between heading and body text. Works
    /// without a selection — the paragraph containing the caret is enough.
    func heading() {
        guard let view = textView, view.isEditable, let storage = view.textStorage else { return }
        let range = (storage.string as NSString).paragraphRange(for: view.selectedRange())
        let current = range.length > 0 ? storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont : nil
        let font = NoteStyle.headingLevel(of: current ?? (view.typingAttributes[.font] as? NSFont) ?? NoteStyle.bodyFont) == nil
            ? NoteStyle.headingFont(level: 2)
            : NoteStyle.bodyFont
        let previous = NSAttributedString(attributedString: storage)
        view.undoManager?.registerUndo(withTarget: self) { controller in
            MainActor.assumeIsolated { controller.restore(previous) }
        }
        storage.beginEditing()
        if range.length > 0 { storage.addAttribute(.font, value: font, range: range) }
        storage.endEditing()
        var typing = view.typingAttributes
        typing[.font] = font
        view.typingAttributes = typing
        view.didChangeText()
        view.window?.makeFirstResponder(view)
    }

    /// Moves focus and the caret to the start of the note body (used when the
    /// user presses Return in the title field).
    func focusBody() {
        guard let view = textView, view.isEditable else { return }
        view.window?.makeFirstResponder(view)
        view.setSelectedRange(NSRange(location: 0, length: 0))
        view.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    func highlight() {
        mutateSelection { storage, range in
            if storage.attribute(.backgroundColor, at: range.location, effectiveRange: nil) != nil {
                storage.removeAttribute(.backgroundColor, range: range)
            } else {
                storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: range)
            }
        }
    }

    func insertBullet() { insert("• ") }
    func insertChecklist() { insert("☐ ") }

    func toggleChecklist() {
        guard let view = textView, view.isEditable else { return }
        let paragraph = (view.string as NSString).paragraphRange(for: view.selectedRange())
        let line = (view.string as NSString).substring(with: paragraph)
        if line.hasPrefix("☐") || line.hasPrefix("☑") {
            view.insertText(line.hasPrefix("☐") ? "☑" : "☐", replacementRange: NSRange(location: paragraph.location, length: 1))
        } else { insertChecklist() }
        view.window?.makeFirstResponder(view)
    }

    private func insert(_ text: String) {
        guard let view = textView, view.isEditable else { return }
        view.window?.makeFirstResponder(view)
        view.insertText(text, replacementRange: view.selectedRange())
    }

    private func mutateSelection(_ mutation: (NSTextStorage, NSRange) -> Void) {
        guard let view = textView, view.isEditable, let storage = view.textStorage else { return }
        let range = view.selectedRange()
        guard range.length > 0 else { return }
        let previous = NSAttributedString(attributedString: storage)
        view.undoManager?.registerUndo(withTarget: self) { controller in
            MainActor.assumeIsolated { controller.restore(previous) }
        }
        storage.beginEditing()
        mutation(storage, range)
        storage.endEditing()
        view.didChangeText()
        view.window?.makeFirstResponder(view)
    }

    private func restore(_ content: NSAttributedString) {
        guard let view = textView, view.isEditable, let storage = view.textStorage else { return }
        let previous = NSAttributedString(attributedString: storage)
        view.undoManager?.registerUndo(withTarget: self) { controller in
            MainActor.assumeIsolated { controller.restore(previous) }
        }
        storage.setAttributedString(content)
        view.didChangeText()
    }
}
