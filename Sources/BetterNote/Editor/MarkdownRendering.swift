import AppKit

@MainActor enum MarkdownRendering {

    // MARK: - Markdown → rich text (import, paste, load of plain-text notes)

    static func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        for (index, raw) in lines.enumerated() {
            let block = renderBlock(raw)
            if index < lines.count - 1 {
                block.mutableString.append("\n")
            }
            result.append(block)
        }
        return result
    }

    private static let headingPattern = try! NSRegularExpression(pattern: #"^(#{1,6})\s+(.*)$"#)
    private static let checkboxPattern = try! NSRegularExpression(pattern: #"^([ \t]*)[-*+][ \t]+\[([ xX])\][ \t]+(.*)$"#)
    private static let bulletPattern = try! NSRegularExpression(pattern: #"^([ \t]*)(?:[-*+]|•|◦|▪)[ \t]+(.*)$"#)
    private static let numberedPattern = try! NSRegularExpression(pattern: #"^([ \t]*)(\d+[.)])[ \t]+(.*)$"#)
    private static let quotePattern = try! NSRegularExpression(pattern: #"^>[ \t]?(.*)$"#)

    private static func renderBlock(_ line: String) -> NSMutableAttributedString {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)

        if let m = headingPattern.firstMatch(in: line, range: full) {
            let level = min((m.range(at: 1).length), 3)
            let content = ns.substring(with: m.range(at: 2))
            return parseInline(content, font: NoteStyle.headingFont(level: level))
        }
        if let m = checkboxPattern.firstMatch(in: line, range: full) {
            let indent = ns.substring(with: m.range(at: 1))
            let marker = ns.substring(with: m.range(at: 2)).lowercased() == "x" ? "☑ " : "☐ "
            let content = parseInline(ns.substring(with: m.range(at: 3)), font: NoteStyle.bodyFont)
            let block = NSMutableAttributedString(string: indent + marker, attributes: NoteStyle.bodyAttributes)
            block.append(content)
            return block
        }
        if let m = bulletPattern.firstMatch(in: line, range: full) {
            let indent = ns.substring(with: m.range(at: 1))
            let content = parseInline(ns.substring(with: m.range(at: 2)), font: NoteStyle.bodyFont)
            let block = NSMutableAttributedString(string: indent + "• ", attributes: NoteStyle.bodyAttributes)
            block.append(content)
            return block
        }
        if let m = numberedPattern.firstMatch(in: line, range: full) {
            let prefix = ns.substring(with: m.range(at: 1)) + ns.substring(with: m.range(at: 2)) + " "
            let content = parseInline(ns.substring(with: m.range(at: 3)), font: NoteStyle.bodyFont)
            let block = NSMutableAttributedString(string: prefix, attributes: NoteStyle.bodyAttributes)
            block.append(content)
            return block
        }
        if let m = quotePattern.firstMatch(in: line, range: full) {
            let content = parseInline(ns.substring(with: m.range(at: 1)), font: NoteStyle.bodyFont)
            let block = NSMutableAttributedString(attributedString: content)
            let all = NSRange(location: 0, length: block.length)
            block.addAttribute(.paragraphStyle, value: NoteStyle.quoteParagraph, range: all)
            block.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: all)
            return block
        }
        return parseInline(line, font: NoteStyle.bodyFont)
    }

    // MARK: - Inline parsing

    private static let inlinePattern = try! NSRegularExpression(
        pattern: #"(\*\*|__)(.+?)\1|`([^`\n]+)`|~~([^\n~]+)~~|\*([^\n*]+)\*|(?<![A-Za-z0-9_])_([^\n_]+)_(?![A-Za-z0-9_])|\[([^\]\n]+)\]\(([^)\s]+)\)"#
    )

    static func parseInline(_ text: String, font: NSFont, attributes base: [NSAttributedString.Key: Any] = [:]) -> NSMutableAttributedString {
        var attrs = base
        attrs[.font] = font
        if attrs[.paragraphStyle] == nil { attrs[.paragraphStyle] = NoteStyle.bodyParagraph }
        if attrs[.foregroundColor] == nil { attrs[.foregroundColor] = NSColor.textColor }
        let output = NSMutableAttributedString()
        let ns = text as NSString
        var cursor = 0
        for match in inlinePattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                output.append(NSAttributedString(string: ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)), attributes: attrs))
            }
            var styled = attrs
            var segment = ""
            if let g = group(2, of: match, in: ns) {
                segment = g
                styled[.font] = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            } else if let g = group(3, of: match, in: ns) {
                segment = g
                styled[.font] = NoteStyle.codeFont
                styled[.backgroundColor] = NSColor.quaternaryLabelColor
            } else if let g = group(4, of: match, in: ns) {
                segment = g
                styled[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            } else if let g = group(5, of: match, in: ns) ?? group(6, of: match, in: ns) {
                segment = g
                styled[.font] = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            } else if let g = group(7, of: match, in: ns), let urlText = group(8, of: match, in: ns) {
                segment = g
                if let url = URL(string: urlText) { styled[.link] = url }
                styled[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                segment = ns.substring(with: match.range)
            }
            output.append(NSAttributedString(string: segment, attributes: styled))
            cursor = NSMaxRange(match.range)
        }
        if cursor < ns.length {
            output.append(NSAttributedString(string: ns.substring(from: cursor), attributes: attrs))
        }
        return output
    }

    private static func group(_ index: Int, of match: NSTextCheckingResult, in ns: NSString) -> String? {
        let range = match.range(at: index)
        return range.location == NSNotFound ? nil : ns.substring(with: range)
    }

    // MARK: - Rich text → Markdown (export, copy)

    static func markdown(from attributed: NSAttributedString) -> String {
        let ns = attributed.string as NSString
        var output = ""
        var location = 0
        while location < ns.length {
            let paragraph = ns.paragraphRange(for: NSRange(location: location, length: 0))
            location = NSMaxRange(paragraph)
            var content = paragraph
            if content.length > 0, ns.character(at: NSMaxRange(content) - 1) == 0x0A {
                content.length -= 1
            }
            output += markdownLine(in: attributed, content: content, ns: ns)
            output += "\n"
        }
        return output
    }

    private static func markdownLine(in attributed: NSAttributedString, content: NSRange, ns: NSString) -> String {
        guard content.length > 0 else { return "" }
        let attrs = attributed.attributes(at: content.location, effectiveRange: nil)
        var prefix = ""
        var range = content
        if let font = attrs[.font] as? NSFont, let level = NoteStyle.headingLevel(of: font) {
            prefix = String(repeating: "#", count: level) + " "
        } else if NoteStyle.isQuoteParagraph(attrs[.paragraphStyle] as? NSParagraphStyle) {
            prefix = "> "
        } else if ns.substring(with: content).hasPrefix("• ") {
            prefix = "- "
            range.location += 2
            range.length -= 2
        } else if ns.substring(with: content).hasPrefix("☐ ") {
            prefix = "- [ ] "
            range.location += 2
            range.length -= 2
        } else if ns.substring(with: content).hasPrefix("☑ ") {
            prefix = "- [x] "
            range.location += 2
            range.length -= 2
        }
        return prefix + inlineMarkdown(in: attributed, range: range, ns: ns)
    }

    private static func inlineMarkdown(in attributed: NSAttributedString, range: NSRange, ns: NSString) -> String {
        var output = ""
        var location = range.location
        let end = NSMaxRange(range)
        let fontManager = NSFontManager.shared
        while location < end {
            var effective = NSRange()
            let attrs = attributed.attributes(at: location, longestEffectiveRange: &effective, in: range)
            var segment = ns.substring(with: effective)
            let font = attrs[.font] as? NSFont ?? NoteStyle.bodyFont
            let isHeading = NoteStyle.headingLevel(of: font) != nil
            if let link = attrs[.link] {
                let target = (link as? URL)?.absoluteString ?? (link as? String) ?? ""
                segment = "[\(segment)](\(target))"
            } else {
                let traits = fontManager.traits(of: font)
                if font.isFixedPitch {
                    segment = "`\(segment)`"
                } else {
                    if (attrs[.strikethroughStyle] as? Int ?? 0) != 0 { segment = "~~\(segment)~~" }
                    if traits.contains(.boldFontMask), !isHeading { segment = "**\(segment)**" }
                    if traits.contains(.italicFontMask) { segment = "*\(segment)*" }
                }
                if attrs[.backgroundColor] != nil { segment = "==\(segment)==" }
            }
            output += segment
            location = NSMaxRange(effective)
        }
        return output
    }
}
