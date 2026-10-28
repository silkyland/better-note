import Testing
import AppKit
@testable import BetterNote

@MainActor struct EditorTests {
    @Test func formattingPreservesUnselectedText() throws {
        let controller = EditorController()
        let view = NSTextView()
        controller.textView = view
        view.textStorage?.setAttributedString(NSAttributedString(string: "one two", attributes: [.font: NSFont.systemFont(ofSize: 17)]))
        view.setSelectedRange(NSRange(location: 0, length: 3))
        controller.bold()
        let storage = try #require(view.textStorage)
        let boldFont = try #require(storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let plainFont = try #require(storage.attribute(.font, at: 4, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))
        #expect(!NSFontManager.shared.traits(of: plainFont).contains(.boldFontMask))
        controller.bold()
        let reverted = try #require(storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(!NSFontManager.shared.traits(of: reverted).contains(.boldFontMask))
    }

    @Test func checklistTogglesOnlyTheCurrentParagraph() {
        let controller = EditorController()
        let view = NSTextView()
        view.string = "☐ First\n☐ Second"
        controller.textView = view
        view.setSelectedRange(NSRange(location: 12, length: 0))
        controller.toggleChecklist()
        #expect(view.string == "☐ First\n☑ Second")
        controller.toggleChecklist()
        #expect(view.string == "☐ First\n☐ Second")
    }

    @Test func trashedEditorRejectsFormattingAndInsertion() {
        let controller = EditorController()
        let view = NSTextView()
        view.string = "Protected"
        view.isEditable = false
        controller.textView = view
        view.setSelectedRange(NSRange(location: 0, length: 9))
        controller.insertChecklist()
        controller.heading()
        controller.bold()
        #expect(view.string == "Protected")
    }

    @Test func enterContinuesBulletList() {
        let view = NSTextView()
        view.string = "• milk"
        view.setSelectedRange(NSRange(location: 6, length: 0))
        #expect(EditorTyping.handleNewline(in: view))
        #expect(view.string == "• milk\n• ")
    }

    @Test func enterOnEmptyListItemExitsList() {
        let view = NSTextView()
        view.string = "• milk\n• "
        view.setSelectedRange(NSRange(location: 9, length: 0))
        #expect(EditorTyping.handleNewline(in: view))
        #expect(view.string == "• milk\n")
    }

    @Test func enterIncrementsNumberedList() {
        let view = NSTextView()
        view.string = "1. first"
        view.setSelectedRange(NSRange(location: 8, length: 0))
        #expect(EditorTyping.handleNewline(in: view))
        #expect(view.string == "1. first\n2. ")
    }

    @Test func enterContinuesChecklist() {
        let view = NSTextView()
        view.string = "☑ done\n☐ next"
        view.setSelectedRange(NSRange(location: 15, length: 0))
        #expect(EditorTyping.handleNewline(in: view))
        #expect(view.string == "☑ done\n☐ next\n☐ ")
    }

    @Test func enterAfterHeadingResetsToBody() throws {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSAttributedString(string: "Big title", attributes: [.font: NoteStyle.headingFont(level: 1)]))
        view.setSelectedRange(NSRange(location: 9, length: 0))
        #expect(EditorTyping.handleNewline(in: view))
        let typing = try #require(view.typingAttributes[.font] as? NSFont)
        #expect(NoteStyle.headingLevel(of: typing) == nil)
    }

    @Test func backspaceAfterMarkerRemovesMarker() {
        let view = NSTextView()
        view.string = "• item"
        view.setSelectedRange(NSRange(location: 2, length: 0))
        #expect(EditorTyping.handleBackspace(in: view))
        #expect(view.string == "item")
    }

    @Test func dashSpaceBecomesBullet() {
        let view = NSTextView()
        view.string = "-"
        view.setSelectedRange(NSRange(location: 1, length: 0))
        #expect(EditorTyping.handleSpace(in: view, range: NSRange(location: 1, length: 0)))
        #expect(view.string == "• ")
    }

    @Test func hashSpaceBecomesHeading() throws {
        let view = NSTextView()
        view.string = "#"
        view.setSelectedRange(NSRange(location: 1, length: 0))
        #expect(EditorTyping.handleSpace(in: view, range: NSRange(location: 1, length: 0)))
        let font = try #require(view.typingAttributes[.font] as? NSFont)
        #expect(NoteStyle.headingLevel(of: font) == 1)
        #expect(view.string.isEmpty)
    }

    @Test func closingStarsBoldTheInnerText() throws {
        let view = NSTextView()
        view.string = "see **bold* here"
        view.setSelectedRange(NSRange(location: 11, length: 0))
        #expect(EditorTyping.handleInlineCloser("*", in: view, range: NSRange(location: 11, length: 0)))
        #expect(view.string == "see bold here")
        let storage = try #require(view.textStorage)
        let font = try #require(storage.attribute(.font, at: 4, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        let plain = try #require(storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(!NSFontManager.shared.traits(of: plain).contains(.boldFontMask))
    }

    @Test func closingBacktickFormatsInlineCode() throws {
        let view = NSTextView()
        view.string = "`x"
        view.setSelectedRange(NSRange(location: 2, length: 0))
        #expect(EditorTyping.handleInlineCloser("`", in: view, range: NSRange(location: 2, length: 0)))
        #expect(view.string == "x")
        let storage = try #require(view.textStorage)
        let font = try #require(storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(font.isFixedPitch)
    }

    @Test func markdownImportRendersBlocks() throws {
        let rendered = MarkdownRendering.render("# Title\n\n- one\n- [x] two\n> quoted")
        #expect(rendered.string == "Title\n\n• one\n☑ two\nquoted")
        let headingFont = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NoteStyle.headingLevel(of: headingFont) == 1)
    }

    @Test func markdownExportEmitsSyntax() {
        let bold = NSMutableAttributedString(string: "bold", attributes: [.font: NSFont.boldSystemFont(ofSize: 17)])
        #expect(MarkdownRendering.markdown(from: bold).contains("**bold**"))
        let list = NSAttributedString(string: "• one\n☐ two", attributes: NoteStyle.bodyAttributes)
        let markdown = MarkdownRendering.markdown(from: list)
        #expect(markdown.contains("- one"))
        #expect(markdown.contains("- [ ] two"))
    }

    @Test func versionComparisonHandlesPrereleases() {
        #expect(UpdateChecker.isNewer("1.0.0-beta.2", than: "1.0.0-beta.1"))
        #expect(UpdateChecker.isNewer("1.0.0", than: "1.0.0-beta.9"))
        #expect(!UpdateChecker.isNewer("1.0.0-beta.1", than: "1.0.0-beta.1"))
        #expect(!UpdateChecker.isNewer("1.0.0-beta.1", than: "1.0.0"))
        #expect(UpdateChecker.isNewer("v1.0.1", than: "1.0.0"))
    }

    @Test func formattingUndoSurvivesMovingEditorToAnotherScrollView() throws {
        let controller = EditorController()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        let originalScroll = NSScrollView(frame: window.contentView?.bounds ?? .zero)
        let view = NSTextView()
        view.allowsUndo = true
        view.textStorage?.setAttributedString(NSAttributedString(string: "Keep undo", attributes: [.font: NSFont.systemFont(ofSize: 17)]))
        originalScroll.documentView = view
        window.contentView = originalScroll
        controller.textView = view
        view.setSelectedRange(NSRange(location: 0, length: 9))
        controller.bold()
        let undo = try #require(view.undoManager)
        #expect(undo.canUndo)
        originalScroll.documentView = nil
        let focusScroll = NSScrollView(frame: originalScroll.frame)
        focusScroll.documentView = controller.textView
        window.contentView = focusScroll
        undo.undo()
        let font = try #require(view.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(!NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        #expect(view.string == "Keep undo")
    }

}
