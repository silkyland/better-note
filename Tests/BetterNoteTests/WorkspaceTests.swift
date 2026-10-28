import Testing
import AppKit
@testable import BetterNote

@MainActor struct WorkspaceTests {
    private func makeWorkspace() throws -> (WorkspaceViewModel, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = LibraryFile(url: directory.appendingPathComponent("library.json"))
        try file.save(StarterLibrary.make())
        return (WorkspaceViewModel(file: file), directory)
    }

    @Test func editingSurvivesReloadWithRichTextAndTags() throws {
        let (workspace, directory) = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        workspace.createNote()
        let note = try #require(workspace.selectedNote)
        let attributed = NSAttributedString(string: "A real thought", attributes: [.font: NSFont.boldSystemFont(ofSize: 17)])
        let rtf = try attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        workspace.updateNote(note.id) { $0.title = "Persistence"; $0.text = attributed.string; $0.richText = rtf }
        workspace.addTag(" #Design ", to: note.id)
        workspace.addTag("design", to: note.id)
        workspace.flush()
        let reopened = WorkspaceViewModel(file: LibraryFile(url: directory.appendingPathComponent("library.json")))
        let saved = try #require(reopened.library.notes.first { $0.id == note.id })
        #expect(saved.title == "Persistence")
        #expect(saved.text == "A real thought")
        #expect(saved.richText == rtf)
        #expect(saved.tags == ["design"])
    }

    @Test func trashRestoresWithoutLosingContent() throws {
        let (workspace, directory) = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try #require(workspace.selectedNote)
        workspace.trashSelected()
        #expect(!workspace.visibleNotes.contains { $0.id == original.id })
        workspace.navigate(to: .trash)
        #expect(workspace.selectedNote?.id == original.id)
        workspace.restoreSelected()
        #expect(workspace.selectedNote?.text == original.text)
        #expect(workspace.selectedNote?.isTrashed == false)
        workspace.flush()
    }

    @Test func permanentDeletionOnlyRemovesTrashedNotes() throws {
        let (workspace, directory) = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        let count = workspace.library.notes.count
        workspace.permanentlyDeleteSelected()
        #expect(workspace.library.notes.count == count)
        workspace.trashSelected()
        workspace.navigate(to: .trash)
        workspace.permanentlyDeleteSelected()
        #expect(workspace.library.notes.count == count - 1)
        workspace.flush()
    }

    @Test func searchIncludesBodyAndTagsAndExcludesTrash() throws {
        let (workspace, directory) = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        workspace.query = "HEADPHONES"
        #expect(workspace.visibleNotes.count == 1)
        workspace.query = "getting-started"
        #expect(workspace.visibleNotes.count == 1)
        workspace.selectedID = workspace.visibleNotes.first?.id
        workspace.trashSelected()
        #expect(workspace.visibleNotes.isEmpty)
        workspace.flush()
    }

    @Test func newNoteInNotebookKeepsItsContext() throws {
        let (workspace, directory) = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        workspace.createNotebook(named: " Research ")
        let notebook = try #require(workspace.library.notebooks.last)
        #expect(notebook.name == "Research")
        workspace.createNote()
        #expect(workspace.selectedNote?.notebookID == notebook.id)
        #expect(workspace.visibleNotes.count == 1)
        workspace.flush()
    }

    @Test func damagedLibraryIsPreservedAndCannotBeOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = LibraryFile(url: directory.appendingPathComponent("library.json"))
        let original = Data("invalid json — preserve this".utf8)
        try original.write(to: file.url)
        let workspace = WorkspaceViewModel(file: file)
        #expect(!workspace.canWrite)
        #expect(workspace.errorMessage != nil)
        workspace.createNote()
        workspace.flush()
        #expect(try Data(contentsOf: file.url) == original)
    }

    @Test func failedSaveKeepsChangesInMemoryAndReportsFailure() throws {
        let (workspace, directory) = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try #require(workspace.selectedID)
        try FileManager.default.removeItem(at: directory)
        try Data("block directory".utf8).write(to: directory)
        workspace.updateNote(id) { $0.title = "Keep this thought" }
        workspace.flush()
        #expect(workspace.selectedNote?.title == "Keep this thought")
        #expect(workspace.saveStatus == "Changes not saved")
        #expect(workspace.errorMessage != nil)
    }
}
