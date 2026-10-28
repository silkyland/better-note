import SwiftUI

struct WorkspaceView: View {
    @Bindable var workspace: WorkspaceViewModel
    let editor: EditorController
    var body: some View {
        HSplitView {
            if !workspace.isFocused {
                SidebarView(workspace: workspace).frame(minWidth: 190, idealWidth: 216, maxWidth: 230)
                NoteListView(workspace: workspace).frame(minWidth: 250, idealWidth: 290, maxWidth: 320)
            }
            if let note = workspace.selectedNote {
                NoteEditorView(workspace: workspace, controller: editor, note: note).frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "square.and.pencil").font(.system(size: 44, weight: .ultraLight)).foregroundStyle(Theme.accent)
                    Text("Make room for a thought.").font(.system(size: 28, weight: .medium, design: .serif))
                    Text("Choose a note, or start with a fresh page.").foregroundStyle(.secondary)
                    Button("New note", action: workspace.createNote).buttonStyle(.borderedProminent).disabled(!workspace.canWrite)
                }.frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity).background(Theme.canvas)
            }
        }.tint(Theme.accent).frame(minWidth: workspace.isFocused ? 600 : 920, minHeight: 620)
            .alert("Your notes need attention", isPresented: Binding(get: { workspace.errorMessage != nil }, set: { if !$0 { workspace.errorMessage = nil } })) {
                Button("OK") { workspace.errorMessage = nil }
            } message: { Text(workspace.errorMessage ?? "") }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in workspace.flush() }
    }
}
