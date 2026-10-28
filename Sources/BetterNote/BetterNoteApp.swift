import SwiftUI

@main
struct BetterNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var workspace = WorkspaceViewModel()
    @State private var editor = EditorController()
    @State private var updater = UpdateChecker()
    @AppStorage("appearance") private var appearance = "system"
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("BetterNote", id: "workspace") {
            WorkspaceView(workspace: workspace, editor: editor)
                .onAppear { delegate.workspace = workspace }
                .task { await updater.checkIfNeeded() }
                .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        }
        .defaultSize(width: 1220, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BetterNote") { openWindow(id: "about") }
                Button("Check for Updates…") { Task { await updater.checkNow() } }
            }
            CommandGroup(replacing: .newItem) {
                Button("New note", action: workspace.createNote).keyboardShortcut("n").disabled(!workspace.canWrite)
                Button("Import note…", action: workspace.importNote).keyboardShortcut("o").disabled(!workspace.canWrite)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save", action: workspace.flush).keyboardShortcut("s").disabled(!workspace.canWrite)
                Menu("Export note") {
                    Button("Plain text…") { workspace.exportSelected(as: .text) }
                    Button("Markdown…") { workspace.exportSelected(as: .markdown) }
                    Button("Rich text…") { workspace.exportSelected(as: .richText) }
                }.disabled(workspace.selectedNote == nil)
            }
            CommandMenu("Note") {
                Button("Bold", action: editor.bold).keyboardShortcut("b").disabled(workspace.selectedNote == nil || workspace.selectedNote?.isTrashed == true)
                Button("Italic", action: editor.italic).keyboardShortcut("i").disabled(workspace.selectedNote == nil || workspace.selectedNote?.isTrashed == true)
                Button("Heading", action: editor.heading).disabled(workspace.selectedNote == nil || workspace.selectedNote?.isTrashed == true)
                Button("Highlight selection", action: editor.highlight).disabled(workspace.selectedNote == nil || workspace.selectedNote?.isTrashed == true)
                Divider()
                Button("Insert checklist", action: editor.insertChecklist).keyboardShortcut("l", modifiers: [.command, .shift]).disabled(workspace.selectedNote == nil || workspace.selectedNote?.isTrashed == true)
                Button("Toggle checklist item", action: editor.toggleChecklist).keyboardShortcut("k", modifiers: [.command, .shift]).disabled(workspace.selectedNote == nil || workspace.selectedNote?.isTrashed == true)
                Divider()
                Button("Duplicate note", action: workspace.duplicateSelected).disabled(workspace.selectedNote == nil || workspace.selectedNote?.isTrashed == true)
                Button("Move to Trash", action: workspace.trashSelected).keyboardShortcut(.delete, modifiers: [.command]).disabled(workspace.selectedNote == nil || workspace.selectedNote?.isTrashed == true)
            }
            CommandGroup(after: .sidebar) {
                Picker("Appearance", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Divider()
                Button(workspace.isFocused ? "Leave Focus mode" : "Enter Focus mode") { workspace.isFocused.toggle() }.keyboardShortcut("f", modifiers: [.command, .shift])
                Button("Search notes") { workspace.isFocused = false; workspace.isSearchRequested = true }.keyboardShortcut("f")
            }
        }

        Window("About BetterNote", id: "about") {
            AboutView()
                .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var workspace: WorkspaceViewModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        workspace?.flush()
        if workspace?.saveStatus == "Changes not saved" {
            let alert = NSAlert()
            alert.messageText = "Your latest changes have not been saved."
            alert.informativeText = "Keep BetterNote open to retry saving, or quit and discard unsaved changes."
            alert.addButton(withTitle: "Keep open")
            alert.addButton(withTitle: "Quit anyway")
            return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
        }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
