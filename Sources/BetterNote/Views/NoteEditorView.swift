import SwiftUI

struct NoteEditorView: View {
    @Bindable var workspace: WorkspaceViewModel
    let controller: EditorController
    let note: Note
    @State private var showingTag = false
    @State private var tagName = ""
    @State private var confirmingDelete = false
    @FocusState private var titleFocused: Bool

    private var notebook: Notebook? { workspace.library.notebooks.first { $0.id == note.notebookID } }
    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle().fill(Theme.line).frame(height: 1)
            if note.isTrashed {
                HStack {
                    Label("This note is in Trash", systemImage: "trash")
                    Spacer()
                    Button("Restore", action: workspace.restoreSelected)
                    Button("Delete permanently", role: .destructive) { confirmingDelete = true }
                }.font(.system(size: 12)).padding(14).background(Theme.subtle)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar").font(.system(size: 10))
                    Text(note.createdAt, format: .dateTime.month(.wide).day().year()).font(.system(size: 11))
                    Text("·")
                    Text("\(max(1, note.wordCount / 200)) min read").font(.system(size: 11))
                }.foregroundStyle(.secondary).padding(.top, 36).padding(.bottom, 18)
                TextField("Give this thought a name…", text: Binding(get: { note.title }, set: { title in workspace.updateNote(note.id) { $0.title = title } }), axis: .vertical)
                    .font(.system(size: 34, weight: .semibold, design: .serif)).textFieldStyle(.plain)
                    .lineLimit(1...3).focused($titleFocused).disabled(note.isTrashed).accessibilityLabel("Note title")
                    .onKeyPress(.return) { titleFocused = false; controller.focusBody(); return .handled }
                tagRow.padding(.top, 17).padding(.bottom, 25)
                formatBar
                ZStack(alignment: .topLeading) {
                    if note.text.isEmpty {
                        Text("Start anywhere. This space is yours.").font(.system(size: 17)).foregroundStyle(.tertiary).padding(.top, 8).allowsHitTesting(false)
                    }
                    RichTextEditor(note: note, controller: controller) { text, rtf in
                        workspace.updateNote(note.id) { $0.text = text; $0.richText = rtf }
                    }
                }.padding(.top, 20)
            }.padding(.horizontal, workspace.isFocused ? 72 : 44).frame(maxWidth: 840).frame(maxWidth: .infinity)
            footer
        }.background(Theme.canvas)
            .onChange(of: note.id) { _, _ in titleFocused = note.title.isEmpty }
            .onAppear { if note.title.isEmpty { titleFocused = true } }
            .alert("Delete this note permanently?", isPresented: $confirmingDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete permanently", role: .destructive, action: workspace.permanentlyDeleteSelected)
            } message: { Text("“\(note.displayTitle)” will be removed from this Mac. This cannot be undone.") }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if workspace.isFocused {
                Button { workspace.isFocused = false } label: { Label("Back to notes", systemImage: "sidebar.left") }.buttonStyle(.borderless).font(.system(size: 12))
            } else {
                Menu {
                    ForEach(workspace.library.notebooks) { notebook in
                        Button(notebook.name) { workspace.updateNote(note.id) { $0.notebookID = notebook.id } }
                    }
                } label: {
                    Label(notebook?.name ?? "Notebook", systemImage: notebook?.symbol ?? "book.closed").font(.system(size: 12)).foregroundStyle(.secondary)
                }.menuStyle(.borderlessButton).fixedSize().disabled(note.isTrashed).help("Move to notebook")
                Text("/").foregroundStyle(.tertiary)
                Text("\(note.isTrashed ? "Archived thought" : "Your workspace")").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            ToolButton(title: note.isPinned ? "Unpin note" : "Pin note", symbol: note.isPinned ? "pin.fill" : "pin") { workspace.updateNote(note.id) { $0.isPinned.toggle() } }
                .foregroundStyle(note.isPinned ? Theme.accent : .secondary).disabled(note.isTrashed)
            ToolButton(title: workspace.isFocused ? "Leave Focus · ⇧⌘F" : "Focus · ⇧⌘F", symbol: workspace.isFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") { workspace.isFocused.toggle() }
            Menu {
                Button("Export as text…") { workspace.exportSelected(as: .text) }
                Button("Export as Markdown…") { workspace.exportSelected(as: .markdown) }
                Button("Export as rich text…") { workspace.exportSelected(as: .richText) }
                Button("Copy as Markdown", action: workspace.copySelectedMarkdown)
                Divider()
                Button("Duplicate note", action: workspace.duplicateSelected).disabled(note.isTrashed)
                Button("Move to Trash", role: .destructive, action: workspace.trashSelected).disabled(note.isTrashed)
            } label: { Image(systemName: "ellipsis").frame(width: 24, height: 28) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Note actions")
        }.padding(.horizontal, 24).frame(height: 66)
    }

    private var tagRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) { tags; addTagButton }
            VStack(alignment: .leading, spacing: 7) { ForEach(note.tags, id: \.self) { tag in tagChip(tag) }; addTagButton }
        }
    }
    private var tags: some View { ForEach(note.tags, id: \.self) { tag in tagChip(tag) } }
    private func tagChip(_ tag: String) -> some View {
        Text("# \(tag)").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.accent)
            .padding(.horizontal, 10).padding(.vertical, 5).background(Theme.accent.opacity(0.085), in: Capsule())
            .contextMenu { Button("Remove tag") { workspace.updateNote(note.id) { $0.tags.removeAll { $0 == tag } } }.disabled(note.isTrashed) }
    }
    private var addTagButton: some View {
        Button { showingTag = true } label: { Label("Add tag", systemImage: "plus").font(.system(size: 11)).foregroundStyle(.secondary) }
            .buttonStyle(.plain).disabled(note.isTrashed)
            .popover(isPresented: $showingTag) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connect your thoughts").font(.headline)
                    TextField("Tag name", text: $tagName).textFieldStyle(.roundedBorder).onSubmit(commitTag)
                    Button("Add tag", action: commitTag).disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(18).frame(width: 250)
            }
    }
    private func commitTag() {
        workspace.addTag(tagName, to: note.id)
        tagName = ""
        showingTag = false
    }

    private var formatBar: some View {
        HStack(spacing: 2) {
            ToolButton(title: "Heading", symbol: "textformat.size", action: controller.heading)
            Rectangle().fill(Theme.line).frame(width: 1, height: 16).padding(.horizontal, 9)
            ToolButton(title: "Bold · ⌘B", symbol: "bold", action: controller.bold)
            ToolButton(title: "Italic · ⌘I", symbol: "italic", action: controller.italic)
            ToolButton(title: "Highlight selection", symbol: "highlighter", action: controller.highlight)
            Rectangle().fill(Theme.line).frame(width: 1, height: 16).padding(.horizontal, 9)
            ToolButton(title: "Insert bullet", symbol: "list.bullet", action: controller.insertBullet)
            ToolButton(title: "Insert checklist · ⇧⌘L", symbol: "checklist", action: controller.insertChecklist)
            ToolButton(title: "Toggle checklist item · ⇧⌘K", symbol: "checkmark.circle", action: controller.toggleChecklist)
            Spacer(minLength: 0)
        }.padding(.horizontal, 8).padding(.vertical, 5).background(Theme.subtle, in: RoundedRectangle(cornerRadius: 8)).disabled(note.isTrashed)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: workspace.saveStatus == "Saved on this Mac" ? "checkmark.circle" : "clock").foregroundStyle(Theme.accent)
            Text(workspace.saveStatus)
            Spacer()
            Text("\(note.wordCount) words")
            Text("·").padding(.horizontal, 3)
            Text("\(note.text.count) characters")
        }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 26).padding(.vertical, 16)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
