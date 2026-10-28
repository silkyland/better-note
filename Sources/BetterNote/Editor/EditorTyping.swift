import AppKit

/// Notion-style typing behaviors for the note editor: list continuation,
/// markdown block triggers, inline markdown formatting, and smart deletion.
@MainActor enum EditorTyping {

    // MARK: - Enter / Return

    /// Continues a list on Enter, exits the list on an empty item, and resets
    /// a heading paragraph back to body text. Returns true when handled.
    static func handleNewline(in view: NSTextView) -> Bool {
        guard view.isEditable, let storage = view.textStorage else { return false }
        let ns = storage.string as NSString
        let selection = view.selectedRange()
        let paragraph = ns.paragraphRange(for: NSRange(location: selection.location, length: 0))
        let line = ns.substring(with: paragraph)
        if let item = listItem(in: line), selection.location - paragraph.location >= item.markerEnd {
            if item.isEmpty {
                storage.deleteCharacters(in: NSRange(location: paragraph.location, length: item.markerEnd))
                view.setSelectedRange(NSRange(location: paragraph.location, length: 0))
                view.didChangeText()
                view.breakUndoCoalescing()
            } else {
                view.insertText("\n" + item.continuation, replacementRange: selection)
                view.breakUndoCoalescing()
            }
            return true
        }
        if selection.length == 0, ns.length > 0, paragraph.location < ns.length {
            var content = line
            if content.hasSuffix("\n") { content.removeLast() }
            if content.trimmingCharacters(in: .whitespaces).isEmpty,
               let style = storage.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle,
               NoteStyle.isQuoteParagraph(style) {
                storage.addAttribute(.paragraphStyle, value: NoteStyle.bodyParagraph, range: paragraph)
                storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: paragraph)
                view.typingAttributes = NoteStyle.bodyAttributes
                view.didChangeText()
                return true
            }
        }
        if selection.length == 0, selection.location > 0,
           selection.location >= NSMaxRange(paragraph) - 1 {
            var effective = NSRange()
            let font = storage.attribute(.font, at: selection.location - 1, effectiveRange: &effective) as? NSFont
            if let font, NoteStyle.headingLevel(of: font) != nil, effective.location <= selection.location - 1 {
                view.insertText("\n", replacementRange: selection)
                view.typingAttributes = NoteStyle.bodyAttributes
                return true
            }
        }
        return false
    }

    // MARK: - Backspace / Tab

    /// Backspace directly after a list marker removes the marker and turns the
    /// item into a plain paragraph.
    static func handleBackspace(in view: NSTextView) -> Bool {
        guard view.isEditable, let storage = view.textStorage else { return false }
        let selection = view.selectedRange()
        guard selection.length == 0 else { return false }
        let ns = storage.string as NSString
        let paragraph = ns.paragraphRange(for: NSRange(location: selection.location, length: 0))
        let line = ns.substring(with: paragraph)
        guard let item = listItem(in: line), selection.location - paragraph.location == item.markerEnd else { return false }
        storage.deleteCharacters(in: NSRange(location: paragraph.location, length: item.markerEnd))
        view.setSelectedRange(NSRange(location: paragraph.location, length: 0))
        view.didChangeText()
        view.breakUndoCoalescing()
        return true
    }

    /// Tab at the start of a list item indents it by four spaces.
    static func handleTab(in view: NSTextView) -> Bool {
        guard view.isEditable, let storage = view.textStorage else { return false }
        let selection = view.selectedRange()
        guard selection.length == 0 else { return false }
        let ns = storage.string as NSString
        let paragraph = ns.paragraphRange(for: NSRange(location: selection.location, length: 0))
        let line = ns.substring(with: paragraph)
        guard let item = listItem(in: line), selection.location - paragraph.location <= item.markerEnd else { return false }
        storage.insert(NSAttributedString(string: "    "), at: paragraph.location)
        view.setSelectedRange(NSRange(location: selection.location + 4, length: 0))
        view.didChangeText()
        view.breakUndoCoalescing()
        return true
    }

    // MARK: - Space triggers (block-level markdown)

    /// Called when a space is typed. Converts a leading marker (`#`, `-`, `*`,
    /// `+`, `[]`, `[ ]`, `>`) into the matching block format. Returns true when
    /// the space was consumed by a transform.
    static func handleSpace(in view: NSTextView, range: NSRange) -> Bool {
        guard view.isEditable, range.length == 0, let storage = view.textStorage else { return false }
        let ns = storage.string as NSString
        let paragraph = ns.paragraphRange(for: NSRange(location: range.location, length: 0))
        let before = ns.substring(with: NSRange(location: paragraph.location, length: range.location - paragraph.location))
        let indentLength = before.prefix(while: { $0 == " " || $0 == "\t" }).count
        let marker = String(before.dropFirst(indentLength))
        switch marker {
        case "#", "##", "###", "####", "#####", "######":
            let level = min(marker.count, 3)
            let font = NoteStyle.headingFont(level: level)
            storage.deleteCharacters(in: NSRange(location: paragraph.location, length: range.location - paragraph.location))
            let updated = (storage.string as NSString).paragraphRange(for: NSRange(location: paragraph.location, length: 0))
            storage.addAttribute(.font, value: font, range: updated)
            view.typingAttributes = [.font: font, .foregroundColor: NSColor.textColor, .paragraphStyle: NoteStyle.bodyParagraph]
            view.setSelectedRange(NSRange(location: paragraph.location, length: 0))
            view.didChangeText()
            view.breakUndoCoalescing()
            return true
        case "-", "*", "+":
            replaceMarker(view, range: NSRange(location: paragraph.location + indentLength, length: marker.count), with: "• ", caretTo: paragraph.location + indentLength + 2)
            return true
        case "[]", "[ ]":
            replaceMarker(view, range: NSRange(location: paragraph.location + indentLength, length: marker.count), with: "☐ ", caretTo: paragraph.location + indentLength + 2)
            return true
        case ">":
            storage.deleteCharacters(in: NSRange(location: paragraph.location + indentLength, length: marker.count))
            let updated = (storage.string as NSString).paragraphRange(for: NSRange(location: paragraph.location, length: 0))
            storage.addAttribute(.paragraphStyle, value: NoteStyle.quoteParagraph, range: updated)
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: updated)
            var typing = view.typingAttributes
            typing[.paragraphStyle] = NoteStyle.quoteParagraph
            typing[.foregroundColor] = NSColor.secondaryLabelColor
            view.typingAttributes = typing
            view.setSelectedRange(NSRange(location: paragraph.location + indentLength, length: 0))
            view.didChangeText()
            view.breakUndoCoalescing()
            return true
        default:
            return false
        }
    }

    private static func replaceMarker(_ view: NSTextView, range: NSRange, with text: String, caretTo location: Int) {
        guard let storage = view.textStorage else { return }
        storage.replaceCharacters(in: range, with: text)
        view.setSelectedRange(NSRange(location: location, length: 0))
        view.didChangeText()
        view.breakUndoCoalescing()
    }

    // MARK: - Inline closers (paired markdown delimiters)

    /// Called when a potential closing delimiter is typed. If it completes an
    /// open/close pair ending at the caret, the delimiters are removed and the
    /// enclosed text is formatted. Returns true when consumed.
    static func handleInlineCloser(_ inserted: String, in view: NSTextView, range: NSRange) -> Bool {
        guard view.isEditable, range.length == 0, let storage = view.textStorage else { return false }
        let ns = storage.string as NSString
        guard range.location > 0 else { return false }
        let paragraph = ns.paragraphRange(for: NSRange(location: range.location, length: 0))
        let before = ns.substring(with: NSRange(location: paragraph.location, length: range.location - paragraph.location))
        let combined = before + inserted
        let combinedLength = (combined as NSString).length
        switch inserted {
        case "*":
            if before.hasSuffix("*"),
               let m = firstMatch(#"\*\*([^\n*]+)\*\*$"#, in: combined, endingAt: combinedLength) {
                return applyPair(m, opening: 2, closing: 2, in: view, paragraph: paragraph, inserted: inserted) { storage, inner in
                    convertFonts(in: storage, range: inner) { NSFontManager.shared.convert($0, toHaveTrait: .boldFontMask) }
                }
            }
            if let m = firstMatch(#"(?<![A-Za-z0-9*])\*([^\n*]+)\*$"#, in: combined, endingAt: combinedLength) {
                return applyPair(m, opening: 1, closing: 1, in: view, paragraph: paragraph, inserted: inserted) { storage, inner in
                    convertFonts(in: storage, range: inner) { NSFontManager.shared.convert($0, toHaveTrait: .italicFontMask) }
                }
            }
        case "_":
            if before.hasSuffix("_"),
               let m = firstMatch(#"__([^\n_]+)__$"#, in: combined, endingAt: combinedLength) {
                return applyPair(m, opening: 2, closing: 2, in: view, paragraph: paragraph, inserted: inserted) { storage, inner in
                    convertFonts(in: storage, range: inner) { NSFontManager.shared.convert($0, toHaveTrait: .boldFontMask) }
                }
            }
            if let m = firstMatch(#"(?<![A-Za-z0-9_])_([^\n_]+)_$"#, in: combined, endingAt: combinedLength) {
                return applyPair(m, opening: 1, closing: 1, in: view, paragraph: paragraph, inserted: inserted) { storage, inner in
                    convertFonts(in: storage, range: inner) { NSFontManager.shared.convert($0, toHaveTrait: .italicFontMask) }
                }
            }
        case "~":
            if before.hasSuffix("~"),
               let m = firstMatch(#"~~([^\n~]+)~~$"#, in: combined, endingAt: combinedLength) {
                return applyPair(m, opening: 2, closing: 2, in: view, paragraph: paragraph, inserted: inserted) { storage, inner in
                    storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: inner)
                }
            }
        case "`":
            if let m = firstMatch(#"`([^`\n]+)`$"#, in: combined, endingAt: combinedLength) {
                return applyPair(m, opening: 1, closing: 1, in: view, paragraph: paragraph, inserted: inserted) { storage, inner in
                    storage.addAttribute(.font, value: NoteStyle.codeFont, range: inner)
                    storage.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: inner)
                }
            }
        case ")":
            if let m = firstMatch(#"\[([^\]\n]+)\]\(([^)\s]+)\)$"#, in: combined, endingAt: combinedLength),
               let url = URL(string: (combined as NSString).substring(with: m.range(at: 2))) {
                return applyLink(m, url: url, in: view, paragraph: paragraph)
            }
        default:
            break
        }
        return false
    }

    /// Applies a paired-delimiter transform. `match` spans opening + inner +
    /// closing inside the paragraph prefix (including the just-typed char).
    private static func applyPair(_ match: NSTextCheckingResult, opening: Int, closing: Int,
                                  in view: NSTextView, paragraph: NSRange, inserted: String,
                                  style: (NSTextStorage, NSRange) -> Void) -> Bool {
        guard let storage = view.textStorage else { return false }
        storage.beginEditing()
        storage.insert(NSAttributedString(string: inserted), at: paragraph.location + NSMaxRange(match.range) - 1)
        let whole = NSRange(location: paragraph.location + match.range.location, length: match.range.length)
        let openRange = NSRange(location: whole.location, length: opening)
        let closeRange = NSRange(location: NSMaxRange(whole) - closing, length: closing)
        let innerRange = NSRange(location: NSMaxRange(openRange), length: closeRange.location - NSMaxRange(openRange))
        storage.deleteCharacters(in: closeRange)
        style(storage, innerRange)
        storage.deleteCharacters(in: openRange)
        storage.endEditing()
        view.setSelectedRange(NSRange(location: openRange.location + innerRange.length, length: 0))
        view.didChangeText()
        view.breakUndoCoalescing()
        return true
    }

    /// Replaces `[text](url)` (the `)` is the just-typed char and not yet in
    /// the document) with `text` carrying a link attribute.
    private static func applyLink(_ match: NSTextCheckingResult, url: URL,
                                  in view: NSTextView, paragraph: NSRange) -> Bool {
        guard let storage = view.textStorage else { return false }
        let label = (storage.string as NSString).substring(with: NSRange(location: paragraph.location + match.range(at: 1).location, length: match.range(at: 1).length))
        let whole = NSRange(location: paragraph.location + match.range.location, length: match.range.length - 1)
        storage.beginEditing()
        storage.replaceCharacters(in: whole, with: label)
        storage.addAttribute(.link, value: url, range: NSRange(location: whole.location, length: label.utf16.count))
        storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: whole.location, length: label.utf16.count))
        storage.endEditing()
        view.setSelectedRange(NSRange(location: whole.location + label.utf16.count, length: 0))
        view.didChangeText()
        view.breakUndoCoalescing()
        return true
    }

    private static func convertFonts(in storage: NSTextStorage, range: NSRange, _ convert: (NSFont) -> NSFont) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = value as? NSFont ?? NoteStyle.bodyFont
            storage.addAttribute(.font, value: convert(font), range: subrange)
        }
    }

    private static func firstMatch(_ pattern: String, in text: String, endingAt end: Int) -> NSTextCheckingResult? {
        let regex = try! NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: end)),
              NSMaxRange(match.range) == end else { return nil }
        return match
    }

    // MARK: - List prefix parsing

    private struct ListItem {
        var markerEnd: Int
        var continuation: String
        var isEmpty: Bool
    }

    private static let checkboxList = try! NSRegularExpression(pattern: #"^([ \t]*)(☐|☑)([ \t]+|$)"#)
    private static let numberedList = try! NSRegularExpression(pattern: #"^([ \t]*)(\d+)([.)])([ \t]+|$)"#)
    private static let bulletList = try! NSRegularExpression(pattern: #"^([ \t]*)(•|◦|▪|[-*+])([ \t]+|$)"#)

    private static func listItem(in line: String) -> ListItem? {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        func item(markerEnd: Int, continuation: String) -> ListItem {
            let rest = ns.substring(from: markerEnd).trimmingCharacters(in: .whitespacesAndNewlines)
            return ListItem(markerEnd: markerEnd, continuation: continuation, isEmpty: rest.isEmpty)
        }
        if let m = checkboxList.firstMatch(in: line, range: full) {
            let indent = ns.substring(with: m.range(at: 1))
            return item(markerEnd: NSMaxRange(m.range), continuation: indent + "☐ ")
        }
        if let m = numberedList.firstMatch(in: line, range: full) {
            let indent = ns.substring(with: m.range(at: 1))
            let number = Int(ns.substring(with: m.range(at: 2))) ?? 0
            let delimiter = ns.substring(with: m.range(at: 3))
            return item(markerEnd: NSMaxRange(m.range), continuation: "\(indent)\(number + 1)\(delimiter) ")
        }
        if let m = bulletList.firstMatch(in: line, range: full) {
            let indent = ns.substring(with: m.range(at: 1))
            let marker = ns.substring(with: m.range(at: 2))
            let normalized = (marker == "-" || marker == "*" || marker == "+") ? "•" : marker
            return item(markerEnd: NSMaxRange(m.range), continuation: "\(indent)\(normalized) ")
        }
        return nil
    }
}
