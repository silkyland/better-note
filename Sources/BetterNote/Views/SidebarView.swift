import SwiftUI

struct SidebarView: View {
    @Bindable var workspace: WorkspaceViewModel
    @State private var showingNotebook = false
    @State private var notebookName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil").font(.system(size: 22, weight: .medium)).foregroundStyle(Theme.accent)
                Text("BetterNote").font(.system(size: 20, weight: .semibold, design: .rounded))
            }.padding(.horizontal, 22).padding(.top, 26).padding(.bottom, 6)
            Text("A little room to think.").font(.system(size: 12)).foregroundStyle(.secondary).padding(.leading, 22).padding(.bottom, 27)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    row("All notes", symbol: "square.stack", scope: .all)
                    row("Pinned", symbol: "pin", scope: .pinned)
                    row("Recently edited", symbol: "clock", scope: .recent)
                    HStack {
                        sectionLabel("NOTEBOOKS")
                        Spacer()
                        Button { showingNotebook = true } label: { Image(systemName: "plus").font(.system(size: 12)) }
                            .buttonStyle(.borderless).help("New notebook").accessibilityLabel("New notebook")
                    }.padding(.top, 28).padding(.bottom, 8).padding(.horizontal, 12)
                    ForEach(workspace.library.notebooks) { notebook in
                        row(notebook.name, symbol: notebook.symbol, scope: .notebook(notebook.id), color: Theme.notebookColor(notebook.colorIndex))
                    }
                    if !workspace.allTags.isEmpty {
                        sectionLabel("TAGS").padding(.top, 28).padding(.bottom, 10).padding(.leading, 12)
                        ForEach(workspace.allTags, id: \.self) { tag in
                            Button { workspace.navigate(to: .tag(tag)) } label: {
                                HStack(spacing: 10) {
                                    Text("#").foregroundStyle(Theme.accent)
                                    Text(tag).lineLimit(1)
                                    Spacer()
                                }.font(.system(size: 13)).padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(workspace.scope == .tag(tag) ? Theme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            }.buttonStyle(.plain)
                        }
                    }
                    row("Trash", symbol: "trash", scope: .trash).padding(.top, 28)
                }.padding(.horizontal, 12)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) { Circle().fill(Theme.accent).frame(width: 6, height: 6); Text("LOCAL WORKSPACE").font(.system(size: 10, weight: .semibold)).tracking(1) }
                Text("Your thoughts. Your Mac.").font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(22)
        }
        .background(Theme.sidebar)
        .sheet(isPresented: $showingNotebook) {
            VStack(alignment: .leading, spacing: 18) {
                Text("A home for your notes").font(.title2.bold())
                TextField("Notebook name", text: $notebookName).textFieldStyle(.roundedBorder).onSubmit(createNotebook)
                HStack {
                    Button("Cancel") { showingNotebook = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Create notebook", action: createNotebook).keyboardShortcut(.defaultAction)
                        .disabled(notebookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(28).frame(width: 360)
        }
    }

    private func createNotebook() {
        workspace.createNotebook(named: notebookName)
        notebookName = ""
        showingNotebook = false
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary)
    }

    private func row(_ title: String, symbol: String, scope: NoteScope, color: Color = Theme.accent) -> some View {
        let selected = workspace.scope == scope
        return Button { workspace.navigate(to: scope) } label: {
            HStack(spacing: 11) {
                Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(selected ? Theme.accent : color).frame(width: 18)
                Text(title).font(.system(size: 13, weight: selected ? .semibold : .regular)).lineLimit(1)
                Spacer(minLength: 2)
                Text("\(workspace.count(in: scope))").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }.padding(.horizontal, 12).padding(.vertical, 10)
                .background(selected ? Theme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
