import Foundation

struct LibraryFile {
    let url: URL

    static var applicationFile: LibraryFile {
        let directory = URL.applicationSupportDirectory.appendingPathComponent("com.devded.betternote", isDirectory: true)
        return LibraryFile(url: directory.appendingPathComponent("library.json"))
    }

    func load() throws -> NoteLibrary? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let library = try JSONDecoder().decode(NoteLibrary.self, from: Data(contentsOf: url))
        guard library.version == 1 else { throw LibraryError.unsupportedVersion }
        guard !library.notebooks.isEmpty,
              Set(library.notebooks.map(\.id)).count == library.notebooks.count,
              Set(library.notes.map(\.id)).count == library.notes.count,
              library.notes.allSatisfy({ note in library.notebooks.contains { $0.id == note.notebookID } })
        else { throw LibraryError.invalidLibrary }
        return library
    }

    func save(_ library: NoteLibrary) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(library).write(to: url, options: .atomic)
    }
}

enum LibraryError: LocalizedError {
    case unsupportedVersion, invalidLibrary
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This library was created by a newer version of BetterNote. The original file has been preserved."
        case .invalidLibrary: "The library contains invalid records. The original file has been preserved."
        }
    }
}
