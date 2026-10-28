# BetterNote

A native macOS notebook for a little room to think. Built with SwiftUI and AppKit, without a web view or third-party runtime.

- Bundle identifier: `com.devded.betternote`
- macOS 14 or newer; Xcode with Swift 6 for development
- Native rich-text editor with undo/redo, spelling, smart quotes, headings, bold, italic, and highlights
- Notebooks, tags, pinned notes, search, two sort orders, and a recoverable Trash
- Focus mode with retained editor undo history
- System, light, and dark appearance from View → Appearance
- UTF-8 text/Markdown and RTF import; text and RTF export
- Automatic local saving, word/character counts, and a save-failure warning

## Run

The installed app is `/Applications/BetterNote.app`. Build products live under `build.noindex` so they do not appear beside the installed app in Spotlight/Finder search.

Open `BetterNote.xcodeproj` in Xcode, choose BetterNote, and run. A generated Xcode project is included, so XcodeGen is optional unless changing `project.yml`.

```sh
./scripts/build.sh
open build.noindex/Build/Products/Release/BetterNote.app
```

The build script creates a locally ad-hoc-signed app. This is a local development build; App Store distribution and notarization require your Apple Developer signing configuration. The supplied Release app is a Universal binary for Apple Silicon and Intel; it requires macOS 14 or newer.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘N | New note |
| ⌘O | Import note |
| ⌘S | Save immediately |
| ⌘F | Search notes |
| ⇧⌘F | Toggle Focus mode |
| ⌘B / ⌘I | Bold / italic |
| ⇧⌘L | Insert a checklist marker |
| ⇧⌘K | Toggle the current checklist item |
| ⌘Delete | Move the selected note to Trash |
| ⌘Z / ⇧⌘Z | Undo / redo |

Select text before applying a heading or highlight. Checklist markers are text, toggled with the toolbar or ⇧⌘K. Add tags from the editor, remove them with their context menu, and move notes using the notebook menu above the editor. Trash notes are read-only until restored. Permanent deletion asks for confirmation.

## Data and recovery

Notes live in `~/Library/Application Support/com.devded.betternote/library.json`. RTF and plain text are stored together in a versioned JSON library. Saves are debounced by 400 ms and written atomically; app deactivation and quitting flush pending changes. If saving fails, the changes stay in memory and quitting offers to keep the app open. A corrupt, incompatible, or structurally invalid library is preserved and saving is disabled.

Back up this directory with Time Machine or copy it while the app is closed. Atomic saving prevents partial writes; it is not a version-history backup. To roll back an app build, keep this directory, replace the `.app`, and reopen it. No migration or network service is involved.

The first launch creates five example notes. Notes remain local; this build has no iCloud sync, attachments, encryption, or collaboration. Imported Markdown remains editable source text rather than rendered Markdown. Keep the application-support directory when removing the app if you want to preserve your notes.

## Verification

```sh
xcodebuild -project BetterNote.xcodeproj -scheme BetterNote \
  -configuration Debug -derivedDataPath build.noindex test CODE_SIGNING_ALLOWED=NO
```

Swift Testing covers rich-text persistence, tag normalization, filtering, notebook context, Trash restoration/deletion, preservation of a corrupt library, failed-save recovery, selected-text formatting, checklist toggling, read-only editing, and formatting undo after reattaching the editor for Focus mode. Tests use isolated temporary libraries.

## App icon

The icon uses a terracotta textured-paper tile and an ivory folded note silhouette, inspired by the visual style of Gitzly. It was generated with built-in imagegen and packaged into all ten standard macOS icon assets, including the 1024px master. The app bundles `BetterNote.icns` directly, matching Gitzly’s packaging and using a full-bleed opaque background that macOS masks to its icon shape without a white background plate. To regenerate asset sizes from another square PNG, run `./scripts/update-icon.sh /path/to/master.png`.
