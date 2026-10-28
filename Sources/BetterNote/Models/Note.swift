import Foundation

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var text: String
    var richText: Data?
    var notebookID: UUID
    var tags: [String] = []
    var isPinned = false
    var isTrashed = false
    var createdAt = Date()
    var updatedAt = Date()

    var displayTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled note" : title }
    var preview: String {
        text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { $0.replacingOccurrences(of: #"^[ \t]*(•|◦|▪|☐|☑|[-*+]|\d+[.)])[ \t]+"#, with: "", options: .regularExpression) }
            .joined(separator: " ")
    }
    var wordCount: Int { text.split { $0.isWhitespace || $0.isNewline }.count }
}

struct Notebook: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var symbol: String
    var colorIndex: Int
}

struct NoteLibrary: Codable {
    var version = 1
    var notebooks: [Notebook]
    var notes: [Note]
}

enum NoteScope: Hashable {
    case all, pinned, recent, trash, notebook(UUID), tag(String)
}
