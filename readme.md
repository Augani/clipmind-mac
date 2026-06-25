# ClipMind

A privacy-first, AI-assisted clipboard manager for macOS. ClipMind keeps a searchable history of everything you copy — text, links, code, images, files — with rich context (source app, window, timestamp, device), and surfaces it through a fast menu-bar carousel and a lean, day-grouped dashboard.

Everything stays on your Mac by default.

## Features

- **Menu-bar carousel** — flip through your most recent copies one card at a time (swipe, scroll, arrow keys, or drag); tap to copy and paste.
- **Timeline dashboard** — day-grouped history with debounced search and filters for date/time, content type, source app, and device.
- **iPhone / iPad capture** — copies that arrive via macOS Universal Clipboard are detected and labeled as coming from your iPhone/iPad instead of the frontmost Mac app.
- **Notch capture HUD** — a tiny animation near the camera notch confirms each capture (toggleable).
- **Workspaces** — group clips by project/app.
- **Multi-paste** — queue several items and paste them in sequence.
- **Sensitive-content detection** — passwords, API keys, and similar are detected and can be auto-deleted.
- **Auto-delete** — optionally purge copies older than N days.
- **Local-first** — SQLite storage on-device; optional Core ML embeddings for semantic search.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later to build

## Build & Run

```bash
git clone <your-fork-url>
cd clipmind
open clipmind.xcodeproj   # then Run the "clipmind" scheme on "My Mac"
```

Or from the command line:

```bash
xcodebuild -scheme clipmind -configuration Debug build
```

On first launch ClipMind asks for **Accessibility** permission (used to read the active window title for clipboard context). It runs as a menu-bar app — look for the clipboard glyph in the top-right menu bar.

## Optional: on-device semantic search

The semantic-search path can use a Core ML sentence-embedding model. The model is **not** bundled in this repo to keep it small; drop a converted `.mlpackage` into `clipmind/Resources/` and wire it into `LocalRAGService` to enable on-device embeddings. Without it, text search still works.

## Optional: Cloudflare backend (`api/`)

The `api/` directory contains an optional Cloudflare Workers backend (sync/notifications). It is not required to run the macOS app. To work on it:

```bash
cd api
npm install
npx wrangler dev
```

Secrets (JWT signing key, etc.) are read from Cloudflare environment bindings — never commit them.

## Privacy

Clipboard history is stored locally in SQLite. Nothing leaves your machine unless you explicitly enable a cloud feature. Sensitive items can be encrypted in the Keychain and auto-deleted.

## License

[MIT](LICENSE) © Augustus Otu
