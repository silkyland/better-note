import SwiftUI

struct NoteListView: View {
    @Bindable var workspace: WorkspaceViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(workspace.scopeTitle).font(.system(size: 22, weight: .semibold))
                    Text("\(workspace.visibleNotes.count) notes · your own pace").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: workspace.createNote) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .medium)).frame(width: 30, height: 30)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9)).foregroundStyle(Theme.canvas)
                }.buttonStyle(.plain).help("New note · ⌘N").accessibilityLabel("New note").disabled(!workspace.canWrite)
            }.padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 21)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search your thoughts", text: $workspace.query).textFieldStyle(.plain).focused($searchFocused).accessibilityLabel("Search notes")
                if !workspace.query.isEmpty {
                    Button { workspace.query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("Clear search")
                } else { Text("⌘F").font(.system(size: 10)).foregroundStyle(.secondary) }
            }.font(.system(size: 12)).padding(10).background(Theme.subtle, in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 20)
            HStack {
                Text(workspace.sortNewestFirst ? "LAST EDITED" : "TITLE").font(.system(size: 9, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Last edited") { workspace.sortNewestFirst = true }
                    Button("Title A–Z") { workspace.sortNewestFirst = false }
                } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 11)) }
                    .menuStyle(.borderlessButton).fixedSize().help("Sort notes").accessibilityLabel("Sort notes")
            }.padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 12)
            if workspace.visibleNotes.isEmpty {
                ContentUnavailableView(workspace.query.isEmpty ? "A fresh page awaits" : "No matching notes", systemImage: workspace.query.isEmpty ? "square.and.pencil" : "magnifyingglass", description: Text(workspace.query.isEmpty ? "Create a note to start something." : "Try another word or notebook."))
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(workspace.visibleNotes) { note in
                                noteCard(note).id(note.id)
                            }
                        }.padding(.horizontal, 12).padding(.bottom, 12)
                    }.onChange(of: workspace.selectedID) { _, id in if let id { proxy.scrollTo(id) } }
                }
            }
            HStack {
                Image(systemName: "lock").font(.system(size: 10))
                Text("Private by default").font(.system(size: 11))
                Spacer()
            }.foregroundStyle(.secondary).padding(.horizontal, 22).padding(.vertical, 15)
        }.background(Theme.canvas)
            .onChange(of: workspace.isSearchRequested) { _, requested in
                if requested { searchFocused = true; workspace.isSearchRequested = false }
            }
            .onAppear {
                if workspace.isSearchRequested { searchFocused = true; workspace.isSearchRequested = false }
            }
    }

    private func noteCard(_ note: Note) -> some View {
        let selected = workspace.selectedID == note.id
        return Button { workspace.selectedID = note.id } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text(note.displayTitle).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                    Spacer(minLength: 4)
                    if note.isPinned { Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(Theme.accent) }
                }
                Text(note.preview.isEmpty ? "Your next thought goes here…" : note.preview).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(note.updatedAt, format: .dateTime.month(.abbreviated).day()).font(.system(size: 10))
                    Spacer()
                    if let tag = note.tags.first { Text("#\(tag)").font(.system(size: 10)).lineLimit(1) }
                }.foregroundStyle(.secondary)
            }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? Theme.accent.opacity(0.085) : Theme.subtle.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Theme.accent.opacity(0.4) : .clear, lineWidth: 1) }
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            .contextMenu {
                if !note.isTrashed {
                    Button(note.isPinned ? "Unpin note" : "Pin note") { workspace.updateNote(note.id) { $0.isPinned.toggle() } }
                    Button("Move to Trash", role: .destructive) { workspace.selectedID = note.id; workspace.trashSelected() }
                } else {
                    Button("Restore note") { workspace.selectedID = note.id; workspace.restoreSelected() }
                }
            }
    }
}

