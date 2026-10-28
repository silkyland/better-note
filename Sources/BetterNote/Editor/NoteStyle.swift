import AppKit

enum NoteStyle {
    static var bodyFont: NSFont { .systemFont(ofSize: 17) }
    static var codeFont: NSFont { .monospacedSystemFont(ofSize: 15, weight: .regular) }

    static var bodyParagraph: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 7
        style.paragraphSpacing = 8
        return style
    }

    static var quoteParagraph: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 7
        style.paragraphSpacing = 8
        style.headIndent = 28
        style.firstLineHeadIndent = 28
        return style
    }

    static var bodyAttributes: [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: NSColor.textColor, .paragraphStyle: bodyParagraph]
    }

    static func headingFont(level: Int) -> NSFont {
        switch level {
        case 1: return NSFont.systemFont(ofSize: 28, weight: .bold)
        case 2: return NSFont.systemFont(ofSize: 24, weight: .semibold)
        default: return NSFont.systemFont(ofSize: 20, weight: .semibold)
        }
    }

    static func headingLevel(of font: NSFont) -> Int? {
        switch font.pointSize {
        case 26...: return 1
        case 22..<26: return 2
        case 19..<22: return 3
        default: return nil
        }
    }

    static func isQuoteParagraph(_ style: NSParagraphStyle?) -> Bool {
        (style?.firstLineHeadIndent ?? 0) >= 28 && (style?.headIndent ?? 0) >= 28
    }
}
