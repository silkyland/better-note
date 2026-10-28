# BetterNote

**A little room to think.** A native macOS notebook built with SwiftUI and AppKit — no web view, no third-party runtime.

[![Release](https://img.shields.io/github/v/release/silkyland/better-note?include_prereleases)](https://github.com/silkyland/better-note/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/silkyland/better-note)
[![Swift](https://img.shields.io/badge/swift-6-orange)](https://swift.org)

## Download

Grab the latest build from [GitHub Releases](https://github.com/silkyland/better-note/releases), unzip, and move `BetterNote.app` to `/Applications`.

The app is ad-hoc signed, so on first launch macOS will ask you to confirm — right-click → **Open**, or allow it in System Settings → Privacy & Security. BetterNote checks GitHub releases for new versions once a day and via **BetterNote → Check for Updates…**.

## Features

- **Notion-style editor** — markdown renders as you type; Enter continues lists, Backspace removes markers
- **Native rich text** — undo/redo, spell checking, smart quotes, headings, bold, italic, highlights, inline code, links
- **Organize** — notebooks, tags, pinned notes, search, two sort orders, recoverable Trash
- **Focus mode** — hides everything but the page, keeps full undo history
- **Import/export** — text, Markdown (rendered), and RTF in; text, Markdown, and RTF out; copy as Markdown
- **Private by default** — automatic local saving to one JSON file, no account, no network calls except update checks
- System, light, and dark appearance (View → Appearance); word and character counts

## Writing

BetterNote is a WYSIWYG editor — there is no raw mode, formatted text is the document. Type markdown and it converts live:

| You type | You get |
| --- | --- |
| `#` + space | Heading 1 (`##`, `###` for smaller) |
| `-`, `*`, `+` + space | Bullet list |
| `[]` or `[ ]` + space | Checklist item |
| `1.` + space | Numbered list (auto-increments) |
| `>` + space | Block quote |
| `**text**`, `__text__` | **Bold** |
| `*text*`, `_text_` | *Italic* |
| `` `text` `` | `Inline code` |
| `~~text~~` | ~~Strikethrough~~ |
| `[text](url)` | Link |

**Enter** inside a list continues it (and splits the item if the caret is mid-line). **Enter** on an empty item, or **Backspace** right after a marker, exits the list. **Enter** at the end of a heading returns to body text. **Return** in the title jumps into the body.

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

## Build from source

Requires macOS 14+ and Xcode with Swift 6. XcodeGen is optional — a generated `BetterNote.xcodeproj` is committed; regenerate it with `xcodegen` only when `project.yml` changes.

```sh
./scripts/build.sh
open build.noindex/Build/Products/Release/BetterNote.app
```

Build products live under `build.noindex` so they stay out of Spotlight/Finder search. The script produces a locally ad-hoc-signed Universal binary (Apple Silicon + Intel); App Store distribution and notarization need your own Apple Developer signing.

### Tests

```sh
xcodebuild -project BetterNote.xcodeproj -scheme BetterNote \
  -configuration Debug -derivedDataPath build.noindex test CODE_SIGNING_ALLOWED=NO
```

Swift Testing covers the editor's typing behaviors (list continuation, markdown triggers, inline formatting), rich-text persistence, tag normalization, filtering, Trash, save-failure recovery, and undo across Focus-mode transitions.

## Data and recovery

Notes live in `~/Library/Application Support/com.devded.betternote/library.json` — RTF and plain text in one versioned JSON file. Saves are debounced (400 ms) and atomic; deactivation and quit flush pending changes. A failed save keeps changes in memory and quitting offers to keep the app open; a corrupt or incompatible library is preserved and saving is disabled.

Back up the directory with Time Machine or copy it while the app is closed. Atomic saving prevents partial writes but is not version history. To roll back an app build, keep the directory, replace the `.app`, and reopen.

## App icon

The icon uses a terracotta textured-paper tile and an ivory folded note silhouette, inspired by the visual style of Gitzly. It is generated for all ten standard macOS sizes plus a bundled `BetterNote.icns`. Regenerate from a square master PNG with `./scripts/update-icon.sh /path/to/master.png`.

## License

[MIT](LICENSE) © 2026 Bundit Nuntates — [devded.com](https://devded.com)

If BetterNote is useful, you can [buy the author a coffee](https://paypal.me/nuntates).
