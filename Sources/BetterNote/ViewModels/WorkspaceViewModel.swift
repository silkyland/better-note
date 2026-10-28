import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class WorkspaceViewModel {
    private(set) var library: NoteLibrary
    var selectedID: UUID?
    var scope: NoteScope = .all
    var query = ""
    var isFocused = false
    var isSearchRequested = false
    var sortNewestFirst = true
    var errorMessage: String?
    private(set) var saveStatus = "Saved on this Mac"
    private(set) var canWrite = true
    private let file: LibraryFile
    private var saveTask: Task<Void, Never>?

    init(file: LibraryFile = .applicationFile) {
        self.file = file
        do {
            if let saved = try file.load() {
                library = saved
            } else {
                library = StarterLibrary.make()
                try file.save(library)
            }
        } catch {
            library = NoteLibrary(notebooks: [], notes: [])
            errorMessage = "Could not open your notes: \(error.localizedDescription)\n\n\(file.url.path)\n\nSaving is disabled to protect the original library."
            canWrite = false
            saveStatus = "Library unavailable"
        }
        selectedID = library.notes.first { !$0.isTrashed }?.id
    }

    var selectedNote: Note? { library.notes.first { $0.id == selectedID } }
    var allTags: [String] { Array(Set(library.notes.filter { !$0.isTrashed }.flatMap(\.tags))).sorted() }
    var scopeTitle: String {
        switch scope {
        case .all: "All notes"
        case .pinned: "Pinned notes"
        case .recent: "Recently edited"
        case .trash: "Trash"
        case .notebook(let id): library.notebooks.first { $0.id == id }?.name ?? "Notebook"
        case .tag(let tag): "#\(tag)"
        }
    }
    var visibleNotes: [Note] {
        library.notes.filter { note in
            let inScope: Bool
            switch scope {
            case .all: inScope = !note.isTrashed
            case .pinned: inScope = !note.isTrashed && note.isPinned
            case .recent: inScope = !note.isTrashed && note.updatedAt > Date().addingTimeInterval(-7 * 86400)
            case .trash: inScope = note.isTrashed
            case .notebook(let id): inScope = !note.isTrashed && note.notebookID == id
            case .tag(let tag): inScope = !note.isTrashed && note.tags.contains(tag)
            }
            let matches = query.isEmpty || "\(note.title) \(note.text) \(note.tags.joined(separator: " "))".localizedStandardContains(query)
            return inScope && matches
        }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return sortNewestFirst ? $0.updatedAt > $1.updatedAt : $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending
        }
    }

    func count(in scope: NoteScope) -> Int {
        switch scope {
        case .all: library.notes.filter { !$0.isTrashed }.count
        case .pinned: library.notes.filter { !$0.isTrashed && $0.isPinned }.count
        case .trash: library.notes.filter(\.isTrashed).count
        case .notebook(let id): library.notes.filter { !$0.isTrashed && $0.notebookID == id }.count
        case .recent: library.notes.filter { !$0.isTrashed && $0.updatedAt > Date().addingTimeInterval(-7 * 86400) }.count
        case .tag(let tag): library.notes.filter { !$0.isTrashed && $0.tags.contains(tag) }.count
        }
    }

    func navigate(to scope: NoteScope) {
        self.scope = scope
        selectedID = visibleNotes.first?.id
    }

    func createNote() {
        guard canWrite, let first = library.notebooks.first else { return }
        let notebookID: UUID
        if case .notebook(let id) = scope { notebookID = id } else { notebookID = first.id }
        let tags: [String]
        if case .tag(let tag) = scope { tags = [tag] } else { tags = [] }
        let note = Note(title: "", text: "", notebookID: notebookID, tags: tags, isPinned: scope == .pinned)
        if scope == .trash { scope = .all }
        query = ""
        library.notes.insert(note, at: 0)
        selectedID = note.id
        scheduleSave()
    }

    func updateNote(_ id: UUID, _ change: (inout Note) -> Void) {
        guard canWrite, let index = library.notes.firstIndex(where: { $0.id == id }) else { return }
        change(&library.notes[index])
        library.notes[index].updatedAt = Date()
        scheduleSave()
    }

    func addTag(_ tag: String, to id: UUID) {
        let cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").lowercased()
        guard !cleaned.isEmpty else { return }
        updateNote(id) { if !$0.tags.contains(cleaned) { $0.tags.append(cleaned) } }
    }

    func createNotebook(named name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canWrite, !cleaned.isEmpty else { return }
        let notebook = Notebook(name: cleaned, symbol: "book.closed", colorIndex: library.notebooks.count % 5)
        library.notebooks.append(notebook)
        navigate(to: .notebook(notebook.id))
        scheduleSave()
    }

    func trashSelected() {
        guard let note = selectedNote else { return }
        updateNote(note.id) { $0.isTrashed = true }
        selectedID = visibleNotes.first?.id
    }

    func restoreSelected() {
        guard let note = selectedNote else { return }
        updateNote(note.id) { $0.isTrashed = false }
        scope = .all
        selectedID = note.id
    }

    func permanentlyDeleteSelected() {
        guard canWrite, let note = selectedNote, note.isTrashed else { return }
        library.notes.removeAll { $0.id == note.id }
        selectedID = visibleNotes.first?.id
        scheduleSave()
    }

    /// Shift+Delete: permanently removes the selected note even when it is
    /// not in Trash yet — the confirmation dialog is the caller's job.
    func permanentlyDeleteSelectedAnyway() {
        guard canWrite, let note = selectedNote else { return }
        library.notes.removeAll { $0.id == note.id }
        selectedID = visibleNotes.first?.id
        scheduleSave()
    }

    func emptyTrash() {
        guard canWrite else { return }
        library.notes.removeAll { $0.isTrashed }
        if selectedNote == nil || selectedNote?.isTrashed == true {
            selectedID = visibleNotes.first?.id
        }
        scheduleSave()
    }

    var trashedCount: Int { library.notes.filter(\.isTrashed).count }

    func duplicateSelected() {
        guard canWrite, var note = selectedNote, !note.isTrashed else { return }
        note.id = UUID()
        note.title = "\(note.displayTitle) — Copy"
        note.createdAt = Date()
        note.updatedAt = Date()
        library.notes.insert(note, at: 0)
        selectedID = note.id
        scheduleSave()
    }

    private func scheduleSave() {
        saveStatus = "Saving…"
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            self?.flush()
        }
    }

    func flush() {
        saveTask?.cancel()
        guard canWrite else { return }
        do {
            try file.save(library)
            saveStatus = "Saved on this Mac"
        } catch {
            saveStatus = "Changes not saved"
            errorMessage = "Could not save your notes: \(error.localizedDescription)\nYour changes remain in memory. Free disk space or check permissions, then choose File → Save."
        }
    }

    func importNote() {
        guard canWrite, let notebook = library.notebooks.first else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .rtf, UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let content = try Data(contentsOf: url)
            var richText: Data?
            let text: String
            if url.pathExtension.lowercased() == "rtf" {
                text = try NSAttributedString(data: content, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string
                richText = content
            } else {
                guard let decoded = String(data: content, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                if ["md", "markdown"].contains(url.pathExtension.lowercased()) {
                    let rendered = MarkdownRendering.render(decoded)
                    text = rendered.string
                    richText = try? rendered.data(from: NSRange(location: 0, length: rendered.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                } else {
                    text = decoded
                }
            }
            let note = Note(title: url.deletingPathExtension().lastPathComponent, text: text, richText: richText, notebookID: notebook.id)
            library.notes.insert(note, at: 0)
            scope = .all
            query = ""
            selectedID = note.id
            scheduleSave()
        } catch { errorMessage = "Import failed: \(error.localizedDescription)" }
    }

    enum ExportFormat { case text, markdown, richText }

    func exportSelected(as format: ExportFormat) {
        guard let note = selectedNote else { return }
        let panel = NSSavePanel()
        let baseName = note.displayTitle.replacingOccurrences(of: "/", with: "-")
        switch format {
        case .text:
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = baseName + ".txt"
        case .markdown:
            panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
            panel.nameFieldStringValue = baseName + ".md"
        case .richText:
            panel.allowedContentTypes = [.rtf]
            panel.nameFieldStringValue = baseName + ".rtf"
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let content: Data
            switch format {
            case .text:
                content = Data((note.displayTitle + "\n\n" + note.text).utf8)
            case .markdown:
                content = Data(("# " + note.displayTitle + "\n\n" + markdownBody(for: note)).utf8)
            case .richText:
                let attributed = NSMutableAttributedString(string: note.displayTitle + "\n\n", attributes: [.font: NSFont.systemFont(ofSize: 26, weight: .bold)])
                let body: NSAttributedString
                if let rtf = note.richText {
                    body = try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
                } else { body = NSAttributedString(string: note.text, attributes: [.font: NSFont.systemFont(ofSize: 16)]) }
                attributed.append(body)
                content = try attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            }
            try content.write(to: url, options: .atomic)
        } catch { errorMessage = "Export failed: \(error.localizedDescription)" }
    }

    func copySelectedMarkdown() {
        guard let note = selectedNote else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("# " + note.displayTitle + "\n\n" + markdownBody(for: note), forType: .string)
    }

    private func markdownBody(for note: Note) -> String {
        if let rtf = note.richText,
           let attributed = try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            return MarkdownRendering.markdown(from: attributed)
        }
        return note.text
    }
}
