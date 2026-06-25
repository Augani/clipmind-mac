# ClipMind - Intelligent Clipboard Manager for macOS

> Your clipboard, supercharged with AI-powered search and organization.

ClipMind is a comprehensive macOS clipboard manager featuring AI-powered semantic search, workspace organization, multi-paste capabilities, and advanced preview features. Built natively for macOS with SwiftUI.

## Features

### Core Clipboard Management
- **📋 Unlimited History**: Never lose important clipboard content again
- **🔍 Powerful Search**: Full-text and semantic search with AI embeddings
- **👁️ Rich Previews**: Beautiful previews for text, code, images, URLs, and files
- **⚡️ Quick Access**: Menu bar and floating search panel (⌘+Shift+V)
- **📦 Multi-Paste**: Queue and paste multiple items sequentially

### AI-Powered Features
- **🤖 Semantic Search**: Find clipboard items by meaning, not just keywords
- **🏷️ Smart Tagging**: Automatic content classification and tagging
- **📝 Code Detection**: Automatic syntax highlighting for 20+ languages
- **🔗 URL Enrichment**: Fetch metadata (title, description, favicon) for URLs
- **📊 Markdown Rendering**: Beautiful markdown preview with syntax highlighting

### Organization & Workspaces
- **📁 Workspaces**: Organize clips by project or context
- **🎨 Color Coding**: Visual workspace identification
- **🔄 Auto-Assignment**: Automatic workspace assignment based on source app
- **🏢 App Filters**: Filter clips by source application

### Privacy & Security
- **🔒 Encryption**: AES-GCM encryption for sensitive content
- **🔐 Auto-Detection**: Detect passwords, API keys, credit cards, SSNs
- **🛡️ Keychain Integration**: Secure storage for sensitive data
- **👁️ Privacy Mode**: Sensitive content badges and warnings

### Advanced Features
- **☁️ iCloud Sync**: Sync clipboard history across your Mac devices
- **🎯 Deduplication**: Smart duplicate detection and merging
- **🧹 Auto-Cleanup**: Automatic archiving of old items
- **📋 AppleScript Support**: Automation and scripting capabilities
- **⌨️ Hotkeys**: Customizable keyboard shortcuts
- **🌓 Dark Mode**: Full dark mode support with adaptive colors
- **♿️ Accessibility**: VoiceOver and accessibility support

### Developer Tools
- **💻 Syntax Highlighting**: 20+ programming languages
- **🔧 Code Formatting**: Auto-format code snippets
- **📄 File Previews**: PDF, image, and document thumbnails
- **🔤 Rich Text**: RTF/RTFD preview with formatting preservation

## Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15+ for building from source

### Build from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/clipmind.git
   cd clipmind
   ```

2. **Open in Xcode**
   ```bash
   cd clipmind
   open clipmind.xcodeproj
   ```

3. **Build and Run**
   - Select the `clipmind` scheme
   - Press ⌘+R to build and run
   - Or ⌘+B to build without running

4. **Grant Permissions**
   - On first launch, grant Accessibility access
   - System Settings → Privacy & Security → Accessibility
   - Enable ClipMind

### Distribution Build

For distribution (notarized build):

```bash
# Configure code signing in Xcode
# Build → Archive
# Distribute App → Direct Distribution
# Upload to Apple for notarization
```

## Usage

### Quick Start

1. **Launch ClipMind**: The app runs in the menu bar (no dock icon)
2. **Copy something**: Copy text, images, files, or URLs as usual
3. **Access history**: Click the menu bar icon or press ⌘+Shift+V
4. **Search**: Type to search your clipboard history
5. **Paste**: Double-click an item or press Enter to paste

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| **Show Floating Search** | ⌘+Shift+V |
| **Show Dashboard** | ⌘+Shift+C |
| **Quick Paste** | Enter |
| **Delete Item** | ⌘+Delete |
| **Copy Item** | ⌘+C |
| **Search** | Start typing |
| **Navigate** | Arrow keys |
| **Close Panel** | Esc |

### Workspaces

Create workspaces to organize your clips:

1. Open Settings → Workspaces
2. Click "Add Workspace"
3. Name it (e.g., "Development", "Work", "Personal")
4. Choose a color
5. Add app filters for auto-assignment

### Semantic Search

ClipMind uses AI embeddings for intelligent search:

- **Exact match**: Search for specific words
- **Semantic match**: Search by meaning ("login credentials" finds passwords)
- **Content type**: Filter by text, code, images, URLs, files
- **Date range**: Find clips from specific time periods

### Multi-Paste

Queue multiple items for sequential pasting:

1. Open Floating Search (⌘+Shift+V)
2. Enable multi-select mode
3. Select multiple items (checkbox or ⌘+click)
4. Click "Paste Stack" or press ⌘+Enter
5. Items paste sequentially with configurable delay

### iCloud Sync

Enable iCloud sync in Settings:

1. Open Settings → iCloud Sync
2. Toggle "Enable Sync"
3. Sensitive items are encrypted before upload
4. Conflicts are resolved with last-write-wins

## Architecture

### Project Structure

```
clipmind/
├── Models/              - Data models (ClipboardItem, Workspace, etc.)
├── Services/            - Business logic and core services
│   ├── ClipboardMonitor.swift      - Clipboard monitoring
│   ├── DatabaseService.swift       - SQLite persistence
│   ├── SecurityService.swift       - Encryption & detection
│   ├── SearchService.swift         - Search functionality
│   ├── WorkspaceService.swift      - Workspace management
│   ├── AI/                         - AI-powered features
│   │   ├── EmbeddingsService.swift
│   │   └── VectorSearchService.swift
│   └── ...
├── Views/               - SwiftUI views
│   ├── MenuBar/                   - Menu bar UI
│   ├── Dashboard/                 - Main dashboard
│   ├── Search/                    - Search interfaces
│   ├── Settings/                  - Settings panels
│   └── Components/                - Reusable components
├── DesignSystem/        - Design tokens and components
├── Utilities/           - Helper classes and extensions
└── Tests/               - Unit and integration tests
```

### Key Technologies

- **SwiftUI**: Modern UI framework
- **SQLite**: Local database for clipboard history
- **CloudKit**: iCloud sync
- **Core ML**: On-device AI embeddings
- **AppKit**: Native macOS APIs (NSPasteboard, AXUIElement)
- **Combine**: Reactive programming
- **CryptoKit**: Encryption (AES-GCM)

### Database Schema

```sql
-- Clipboard items table
CREATE TABLE clipboard_items (
  id TEXT PRIMARY KEY,
  content_type TEXT NOT NULL,
  content_value BLOB NOT NULL,
  item_type TEXT NOT NULL,
  timestamp REAL NOT NULL,
  source_app TEXT NOT NULL,
  source_bundle_id TEXT,
  window_title TEXT,
  workspace_id TEXT,
  embedding BLOB,           -- AI embedding vector
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL
);

-- Metadata table
CREATE TABLE metadata (
  id TEXT PRIMARY KEY,
  clipboard_item_id TEXT NOT NULL,
  tags TEXT,
  usage_count INTEGER DEFAULT 0,
  is_archived INTEGER DEFAULT 0,
  is_sensitive INTEGER DEFAULT 0,
  last_used_at REAL,
  FOREIGN KEY (clipboard_item_id) REFERENCES clipboard_items(id)
);

-- Workspaces table
CREATE TABLE workspaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT,
  app_filter TEXT,          -- JSON array of app names
  project_path TEXT,
  auto_tag_rules TEXT,
  created_at REAL NOT NULL
);
```

### Performance Characteristics

- **Clipboard Capture**: <200ms latency
- **Search**: <100ms for 10,000 items
- **Memory Usage**: <200MB idle, <500MB under load
- **Database Size**: ~500 bytes per text item, variable for images/files
- **Semantic Search**: ~50ms per query with 384-dimensional embeddings

## Configuration

### Settings

All settings are accessible via the Settings panel:

- **General**: Retention period, max items, launch at login
- **AI & Search**: Enable semantic search, embedding model
- **Hotkeys**: Customize keyboard shortcuts
- **Workspaces**: Manage workspaces and auto-assignment
- **Privacy**: Encryption settings, sensitive detection
- **iCloud**: Sync preferences and status
- **Advanced**: Debug logging, database location, cleanup

### Environment Variables

For development:

```bash
# Enable debug logging
CLIPMIND_DEBUG=1

# Custom database path
CLIPMIND_DB_PATH=/path/to/database

# Disable iCloud sync
CLIPMIND_DISABLE_ICLOUD=1
```

## AppleScript Support

ClipMind exposes scriptability for automation:

```applescript
-- Get clipboard history
tell application "ClipMind"
    get clipboard items
end tell

-- Search clipboard
tell application "ClipMind"
    search "password"
end tell

-- Copy item to clipboard
tell application "ClipMind"
    copy item with id "item-uuid-here"
end tell

-- Get workspace items
tell application "ClipMind"
    items in workspace "Development"
end tell
```

## Development

### Running Tests

```bash
# Run unit tests
xcodebuild test -scheme clipmind -destination 'platform=macOS'

# Or in Xcode
⌘+U
```

### Debugging

```bash
# Enable debug logging
defaults write com.clipmind.app DebugLoggingEnabled -bool true

# View logs
log stream --predicate 'subsystem == "com.clipmind.app"' --level debug
```

### Database Inspection

```bash
# Open database
sqlite3 ~/Library/Application\ Support/ClipMind/clipboard.db

# List tables
.tables

# Query items
SELECT * FROM clipboard_items ORDER BY timestamp DESC LIMIT 10;

# Get statistics
SELECT
  COUNT(*) as total_items,
  COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END) as with_embeddings
FROM clipboard_items;
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Coding Standards

- Follow Swift style guide
- Add unit tests for new features
- Update documentation
- Use meaningful commit messages

## Privacy & Security

ClipMind takes privacy seriously:

- **Local-First**: All data stored locally by default
- **Encryption**: Sensitive content encrypted with AES-GCM
- **No Telemetry**: No tracking or analytics
- **Optional Sync**: iCloud sync is opt-in
- **Keychain**: Sensitive credentials stored in macOS Keychain
- **Sandboxed**: App runs in macOS sandbox for security

### What ClipMind Collects

- **Nothing by default**: All data stays on your device
- **iCloud Sync** (opt-in): Encrypted clipboard items synced via CloudKit
- **No Third Parties**: No data sent to external servers

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built with SwiftUI and AppKit
- Syntax highlighting powered by custom Swift implementation
- Markdown rendering with NSAttributedString
- Icons from SF Symbols

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/clipmind/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/clipmind/discussions)
- **Email**: support@clipmind.app

## Roadmap

See [plan.md](plan.md) for the complete development roadmap.

### Upcoming Features

- **Phase 16**: Clip sharing & social features (with API)
- Enhanced AI summarization
- Multi-language support
- iOS companion app
- Browser extensions
- Plugin system

---

**ClipMind** - Copy smarter, not harder. 📋✨
