# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClipMind is a privacy-first, AI-powered clipboard manager for macOS built with SwiftUI. It tracks clipboard history with rich metadata (source app, window title, timestamp), provides semantic search via AI embeddings, and enhances productivity with multi-paste stacks, workspace grouping, and developer-focused utilities.

## Build Commands

### Build the application
```bash
xcodebuild -scheme clipmind -configuration Debug build
```

### Build for release
```bash
xcodebuild -scheme clipmind -configuration Release build
```

### Run in Xcode
Open `clipmind.xcodeproj` in Xcode and run the `clipmind` scheme on "My Mac (Debug)".

### Clean build
```bash
xcodebuild clean -scheme clipmind
```

## Architecture

### Three-Layer Architecture

1. **UI Layer (SwiftUI)**
   - Menu bar integration with status item
   - Floating search panel (⌘+Shift+V hotkey)
   - Dashboard with rich previews and filtering
   - Settings and workspace management views

2. **Daemon Layer (XPC Service)**
   - Background clipboard monitoring via NSPasteboard polling
   - Metadata extraction using NSWorkspace and AXUIElement APIs
   - IPC server for UI communication
   - Automated cleanup and archiving

3. **AI Layer (Local + Cloud)**
   - Local-first: Core ML embeddings for semantic search
   - Cloud fallback: Cloudflare AI API for advanced features
   - Tool calling for snippet enrichment (formatting, validation)

### Data Flow

```
NSPasteboard → ClipboardMonitor → MetadataExtractor → DatabaseService (SQLite)
                                                      ↓
FloatingSearchView → SearchService → LocalRAGService/CloudflareAIService
                                  → Results + AI Suggestions
```

### Key Technical Decisions

- **Storage**: SQLite for flexibility, performance, and large history support
- **Daemon Architecture**: XPC service for IPC between UI and background monitoring
- **AI Strategy**: Local-first with Core ML embeddings, optional cloud AI for advanced features
- **Permissions**: Requires Accessibility API access for window titles and Full Disk Access for comprehensive clipboard monitoring
- **Performance Targets**: <200ms clipboard capture latency, <200MB idle memory usage

## Project Structure

```
clipmind/
├── clipmindApp.swift          # App entry point (menu bar app)
├── ContentView.swift          # Main SwiftUI view
├── Models/                    # Data models
│   ├── ClipboardItem.swift    # Main clipboard entry (text/image/file)
│   ├── SnippetMetadata.swift  # Tags, embeddings, usage stats
│   └── Workspace.swift        # Project/app grouping
├── Services/                  # Business logic layer
│   ├── DatabaseService.swift      # SQLite CRUD operations
│   ├── ClipboardMonitor.swift     # NSPasteboard polling
│   ├── MetadataExtractor.swift    # App/window context capture
│   ├── SearchService.swift        # Hybrid text+semantic search
│   ├── LocalRAGService.swift      # Core ML embeddings
│   ├── CloudflareAIService.swift  # Cloud AI integration
│   ├── AIService.swift            # AI coordinator (local/cloud)
│   ├── MultiPasteService.swift    # Sequential paste queue
│   ├── WorkspaceService.swift     # Project grouping logic
│   ├── SecurityService.swift      # Keychain, sensitive detection
│   └── HotkeyService.swift        # Global shortcuts
├── Views/                     # SwiftUI views
│   ├── MenuBarView.swift          # Status bar UI
│   ├── FloatingSearchView.swift   # Search panel (⌘+Shift+V)
│   ├── DashboardView.swift        # Main history view
│   ├── SettingsView.swift         # Preferences
│   └── WorkspaceManagerView.swift # Workspace configuration
└── Daemon/                    # Background service
    ├── main.swift             # XPC service entry
    ├── IPCServer.swift        # UI↔Daemon communication
    └── CleanupManager.swift   # Auto-archiving, deduplication
```

## Core Features Implementation Plan

### Phase 1: Foundation (Days 1-2)
- Create Models/ and Services/ folder structure
- Implement ClipboardItem, SnippetMetadata, Workspace models
- Build DatabaseService with SQLite tables and migrations
- Add SecurityService for Keychain integration

### Phase 2: Clipboard Monitoring (Days 3-4)
- Build ClipboardMonitor with NSPasteboard.changeCount polling
- Implement MetadataExtractor (app/window title capture via AXUIElement)
- Create XPC daemon service with IPCServer for UI communication
- Target: <200ms capture latency

### Phase 3: UI & Search (Days 5-6)
- Convert app to menu bar-only (no dock icon)
- Create FloatingSearchView with ⌘+Shift+V hotkey
- Build DashboardView with filtering and rich previews
- Implement text-based SearchService

### Phase 4: Multi-Paste & Workspaces (Days 7-8)
- Build MultiPasteService for sequential paste operations
- Implement WorkspaceService for project-based grouping
- Add workspace auto-assignment based on app/project path

### Phase 5: AI Integration (Days 9-13)
- Implement LocalRAGService with Core ML embeddings
- Build CloudflareAIService for cloud AI features
- Create AIService coordinator with local-first strategy
- Add semantic search and AI-powered tagging

### Phases 6-16: Advanced Features
See plan.md for complete roadmap including rich previews, cleanup automation, hotkeys, iCloud sync, CLI/AppleScript, and distribution preparation.

## Development Workflow

### Permissions Setup
The app requires:
- **Accessibility API**: For window title extraction via AXUIElement
- **Full Disk Access**: For comprehensive clipboard monitoring
- These are requested on first launch with user-facing explanations

### Database Schema
```sql
clipboard_items: id, content, type, timestamp, sourceApp, windowTitle, workspaceId
metadata: id, clipboardItemId, tags, embedding, usageCount, isArchived, isSensitive
workspaces: id, name, color, appFilter, projectPath, autoTagRules
```

### IPC Protocol
UI communicates with daemon via XPC service methods:
- `getHistory(limit:filter:) -> [ClipboardItem]`
- `search(query:mode:) -> [ClipboardItem]`
- `paste(items:[ClipboardItem])`
- `cleanup(strategy:)`

## AI Integration Details

### Local RAG (Offline Mode)
- Core ML embedding model for semantic search
- Vector similarity search using cosine distance
- Embeddings stored in SQLite for fast retrieval
- Batch generation for existing history

### Cloud AI (Online Mode)
- Cloudflare Workers AI API for advanced features
- Embedding generation, snippet summarization, tagging
- Tool calling: code formatting, JSON validation, URL enrichment
- Rate limiting and cost tracking

### Hybrid Strategy
- Default to local embeddings for search
- Fallback to cloud for enrichment and advanced features
- User preference controls AI mode

## Security & Privacy

- **Local-First Architecture**: No data leaves machine without consent
- **Sensitive Content Detection**: Regex patterns for passwords, API keys
- **Keychain Encryption**: Secure storage for sensitive clipboard items
- **Sandbox Compliance**: Proper entitlements for App Sandbox
- **Code Signing**: Required for distribution and notarization

## Performance Targets

| Metric                    | Target        |
|---------------------------|---------------|
| Clipboard capture latency | <200ms        |
| Semantic search relevance | ≥85% accuracy |
| Memory usage (idle)       | <200MB        |
| Multi-paste reliability   | 100%          |
| Crash-free runtime        | 99% over 24h  |

## Known Limitations

- Requires macOS 14+ for SwiftUI features
- Accessibility API access required for window titles
- Large clipboard history (>10k items) may require pagination
- Clipboard monitoring polling interval affects latency/CPU trade-off
