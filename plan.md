# ClipMind Complete Build Plan

## Overview

Build ClipMind as a comprehensive macOS clipboard manager with AI capabilities, following the architecture in readme.md. This plan covers all core features and future enhancements in a structured, incremental approach.

## Phase 1: Foundation & Data Layer (Days 1-2)

### 1.1 Project Structure Setup

- Create folder structure: Models/, Services/, Views/, Daemon/, Utilities/
- Configure Xcode project with proper groups
- Set up Info.plist with required permissions (Accessibility, Full Disk Access)
- Configure entitlements for sandboxing and XPC communication

### 1.2 Core Data Models

**Files:**

- `Models/ClipboardItem.swift` - Main clipboard entry model
- Properties: id, content (text/image/file), type enum, timestamp, sourceApp, windowTitle, workspaceId
- Support for text, images (NSImage), files (URLs)
- `Models/SnippetMetadata.swift` - Extended metadata
- Properties: tags, embedding vector, similarity scores, usage count, isArchived, isSensitive
- `Models/Workspace.swift` - Workspace/project grouping
- Properties: id, name, color, appFilter, projectPath, autoTagRules

### 1.3 Database Layer

**Files:**

- `Services/DatabaseService.swift` - SQLite wrapper
- Create tables: clipboard_items, metadata, workspaces, sync_state (for iCloud)
- CRUD operations with async/await
- Migration support
- Indexes for timestamp, workspace, type searches

### 1.4 Security Layer

**Files:**

- `Services/SecurityService.swift` - Keychain integration
- Encrypt sensitive clipboard items
- Detect passwords/API keys using regex patterns
- Secure storage for API keys (Cloudflare AI)

## Phase 2: Clipboard Monitoring & Capture (Days 3-4)

### 2.1 Clipboard Daemon Architecture

**Files:**

- `Daemon/main.swift` - XPC service entry point
- Configure as Launch Agent or XPC service
- Set up IPC server for UI communication
- `Daemon/IPCServer.swift` - XPC communication layer
- Protocol definition for UI ↔ Daemon communication
- Methods: getHistory, search, paste, cleanup

### 2.2 Clipboard Monitoring

**Files:**

- `Services/ClipboardMonitor.swift` - Core monitoring service
- Use NSPasteboard.changeCount polling (with timer optimization)
- Detect changes: text, images, files
- Capture latency target: <200ms
- Background queue processing
- `Services/MetadataExtractor.swift` - Context extraction
- Get frontmost app using NSWorkspace
- Extract window title using AXUIElement APIs
- Capture timestamp, app bundle ID
- Handle permission requests gracefully

### 2.3 Integration & Logging

**Files:**

- `Services/Logger.swift` - Centralized logging
- Use os.log framework
- Log levels: debug, info, error
- Performance metrics tracking

## Phase 3: Basic UI & Search (Days 5-6)

### 3.1 Menu Bar Integration

**Files:**

- `clipmindApp.swift` - Update app entry point
- Configure as menu bar app (no dock icon)
- Set up NSStatusBar with menu
- `Views/MenuBarView.swift` - Menu bar UI
- Status item with icon
- Quick access menu: Recent items, Search, Settings
- Show unread count badge

### 3.2 Floating Search Panel

**Files:**

- `Views/FloatingSearchView.swift` - Main search interface
- NSPanel with HUD style, always on top
- Text field with real-time filtering
- Results list with preview
- Keyboard shortcuts: ⌘+Shift+V to show, Esc to dismiss
- Paste on Enter, navigate with arrows

### 3.3 Dashboard View

**Files:**

- `Views/DashboardView.swift` - Main window view
- Grid/list view toggle
- Filter by type, workspace, date
- Rich previews: text snippets, image thumbnails, file icons
- Context menu: Copy, Paste, Delete, Archive, Tag

### 3.4 Basic Search Implementation

**Files:**

- `Services/SearchService.swift` - Local search
- Text-based search (content, app, window title)
- Filter by type, date range, workspace
- Sort by date, usage, relevance

## Phase 4: Multi-Paste & Workspaces (Days 7-8)

### 4.1 Multi-Paste Stack

**Files:**

- `Services/MultiPasteService.swift` - Batch paste manager
- Queue selected items
- Sequential paste with delay (configurable)
- Handle paste failures gracefully
- Visual feedback during paste operation
- Update `FloatingSearchView.swift` - Add multi-select UI
- Checkboxes for item selection
- "Paste Stack" button/action

### 4.2 Workspace Management

**Files:**

- `Services/WorkspaceService.swift` - Workspace logic
- Create/edit/delete workspaces
- Auto-assign items to workspaces based on app/project
- Workspace filtering in UI
- `Views/WorkspaceManagerView.swift` - Workspace UI
- List of workspaces with colors
- Create/edit dialog
- Drag-and-drop assignment

## Phase 5: AI Integration - Local RAG (Days 9-11)

### 5.1 Local Embeddings & RAG

**Files:**

- `Services/LocalRAGService.swift` - Local semantic search
- Use Core ML or on-device embedding model (e.g., via SentenceTransformers Swift port)
- Generate embeddings for clipboard items
- Vector similarity search (cosine similarity)
- Store embeddings in database
- Batch embedding generation for existing items

### 5.2 Semantic Search Integration

**Files:**

- Update `Services/SearchService.swift` - Add semantic search
- Hybrid search: combine text + semantic
- Relevance scoring
- Configurable search mode (text-only, semantic-only, hybrid)

### 5.3 AI Suggestions & Tagging

**Files:**

- `Services/AITaggingService.swift` - Intelligent tagging
- Analyze content to suggest tags (code, URL, email, etc.)
- Detect content type automatically
- Suggest workspace assignment
- Update `FloatingSearchView.swift` - Show AI suggestions inline

## Phase 6: Cloud AI Integration (Days 12-13)

### 6.1 Cloudflare AI Service

**Files:**

- `Services/CloudflareAIService.swift` - Cloud AI integration
- API client for Cloudflare Workers AI
- Embedding generation endpoint
- Snippet enrichment (summarize, format, validate)
- Tool calling support (format code, validate JSON, enrich URLs)
- Error handling and retry logic

### 6.2 Hybrid AI Strategy

**Files:**

- Update `Services/AIService.swift` - AI coordinator
- Strategy pattern: local-first, fallback to cloud
- User preference for AI mode (offline, online, hybrid)
- Rate limiting and cost tracking

### 6.3 AI Tool Calling

**Files:**

- `Services/AIToolService.swift` - Tool execution
- Code formatting tools
- JSON validation
- URL enrichment (fetch metadata)
- Safe execution sandbox

## Phase 7: Rich Previews & Developer Tools (Days 14-15)

### 7.1 Enhanced Previews

**Files:**

- `Views/PreviewComponents.swift` - Rich preview views
- Image thumbnails with NSImage
- PDF preview generation
- Code block formatting with syntax highlighting
- URL preview with metadata (title, description, favicon)
- File type icons

### 7.2 Developer Utilities

**Files:**

- `Services/DeveloperService.swift` - Dev-specific features
- Detect code snippets (language detection)
- Auto-format code (integrate with formatters)
- Terminal integration (paste to terminal)
- VSCode integration (paste to editor)
- Code snippet templates

## Phase 8: Cleanup & Archiving (Day 16)

### 8.1 Deduplication

**Files:**

- `Services/DeduplicationService.swift` - Smart deduplication
- Content-based duplicate detection
- Fuzzy matching for similar items
- Merge duplicates, keep metadata
- User review workflow

### 8.2 Auto-Archiving

**Files:**

- `Daemon/CleanupManager.swift` - Background cleanup
- Archive old items (configurable retention)
- Daily digest generation
- Low disk space handling
- Scheduled cleanup tasks

## Phase 9: Settings & Preferences (Day 17)

### 9.1 Settings UI

**Files:**

- `Views/SettingsView.swift` - Comprehensive settings
- General: retention period, max items
- AI: provider selection, API keys, offline mode
- Hotkeys: customizable shortcuts
- Privacy: encryption settings, sensitive detection
- Workspaces: default workspace, auto-tagging rules
- Advanced: debug logging, database location

### 9.2 Preferences Storage

**Files:**

- `Services/PreferencesService.swift` - UserDefaults wrapper
- Type-safe preference access
- Migration for preference changes

## Phase 10: Hotkeys & Quick Actions (Day 18)

### 10.1 Global Hotkey System

**Files:**

- `Services/HotkeyService.swift` - Global shortcuts
- Use Carbon/Cocoa hotkey APIs
- Register/unregister hotkeys
- Handle conflicts gracefully
- Default: ⌘+Shift+V for search, ⌘+Shift+C for history

### 10.2 Quick Actions

**Files:**

- Update `FloatingSearchView.swift` - Quick actions
- Keyboard shortcuts for common actions
- Command palette style interface

## Phase 11: Future Enhancements - iCloud Sync (Days 19-21)

### 11.1 iCloud Integration

**Files:**

- `Services/iCloudSyncService.swift` - CloudKit integration
- Use CloudKit for sync
- Encrypt sensitive items before sync
- Conflict resolution (last-write-wins with user review)
- Sync state tracking
- Background sync with NSOperationQueue

### 11.2 Sync UI

**Files:**

- Update `SettingsView.swift` - Add sync section
- Enable/disable sync toggle
- Sync status indicator
- Manual sync trigger
- Conflict resolution UI

## Phase 12: Future Enhancements - Smart Auto-Tagging (Days 22-23)

### 12.1 AI-Powered Context Detection

**Files:**

- `Services/SmartTaggingService.swift` - Predictive tagging
- Analyze app context, project paths, window titles
- Predict workspace assignment
- Learn from user corrections
- Use local ML model or cloud AI

### 12.2 Auto-Tagging Rules

**Files:**

- Update `Models/Workspace.swift` - Add auto-tag rules
- Rule engine: app-based, path-based, keyword-based
- User-defined rules UI

## Phase 13: Future Enhancements - AI Summarization (Day 24)

### 13.1 Multi-Snippet Summarization

**Files:**

- `Services/SummarizationService.swift` - AI summarization
- Select multiple snippets
- Generate summary using AI (local or cloud)
- Extract key points, themes
- Create summary snippet

### 13.2 UI Integration

**Files:**

- Update `DashboardView.swift` - Add summarize action
- Multi-select with summarize button
- Show summary in preview

## Phase 14: Future Enhancements - CLI & AppleScript (Days 25-26)

### 14.1 Command Line Interface

**Files:**

- `CLI/clipmind.swift` - CLI tool
- Commands: list, search, paste, delete, sync
- JSON output option
- Integration with shell scripts
- Create separate CLI target in Xcode

### 14.2 AppleScript Support

**Files:**

- `Utilities/AppleScriptBridge.swift` - Scriptability
- Define AppleScript dictionary
- Expose clipboard items, workspaces
- Enable automation workflows

## Phase 15: Future Enhancements - Enhanced Previews (Day 27)

### 15.1 PDF & Advanced Previews

**Files:**

- Update `Views/PreviewComponents.swift`
- PDF thumbnail generation using PDFKit
- Enhanced code formatting with language detection
- Markdown rendering
- Rich text preview

## Phase 16: Future Enhancements - Clip Sharing & Social Features (Days 28-30)

### 16.1 User Account System

**Files:**

- `Models/User.swift` - User account model
- Properties: id, clippyUsername (unique), email, displayName, avatar, isPublic, createdAt
- Username validation (alphanumeric, 3-20 chars, unique)
- `Services/AuthenticationService.swift` - Account management
- Sign up flow (opt-in, email verification optional)
- Sign in/sign out
- Token-based authentication (JWT or similar)
- Secure credential storage in Keychain
- `Services/UserService.swift` - User profile management
- Update profile, change username (with cooldown)
- Privacy settings (public/private profile)
- Block/unblock users

### 16.2 Backend API Integration

**Files:**

- `Services/ClipSharingService.swift` - Sharing API client
- REST API client for ClipMind backend service
- Endpoints: /api/users, /api/clips/share, /api/clips/received, /api/users/search
- End-to-end encryption for shared clips (optional)
- Rate limiting and error handling
- `Models/SharedClip.swift` - Shared clip model
- Properties: id, senderUsername, recipientUsername, content, type, timestamp, message, isRead
- Link shared clips to local ClipboardItem

### 16.3 Sharing UI

**Files:**

- `Views/ShareClipView.swift` - Share interface
- Username search/autocomplete
- Share dialog with recipient selection
- Optional message/note field
- Share history (sent clips)
- `Views/ReceivedClipsView.swift` - Inbox for shared clips
- List of received clips with sender info
- Preview, accept, decline actions
- Notification badge for unread shares
- Update `DashboardView.swift` - Add "Share" action to context menu
- Quick share button in FloatingSearchView
- Share indicator badge on shared clips

### 16.4 Database Schema Updates

**Files:**

- Update `Services/DatabaseService.swift` - Add sharing tables
- Tables: users, shared_clips, user_contacts, share_settings
- Foreign keys to clipboard_items
- Indexes for username lookups, recipient queries
- Migration support for existing databases

### 16.5 Notification System

**Files:**

- `Services/NotificationService.swift` - Push notifications
- Local notifications for received clips
- Background sync to check for new shares
- Notification preferences (enable/disable, quiet hours)
- Update `MenuBarView.swift` - Show unread share count badge

### 16.6 Privacy & Security

**Files:**

- Update `Services/SecurityService.swift` - Sharing security
- Encrypt sensitive clips before sharing (user choice)
- Validate recipient usernames before sending
- Rate limiting for share requests
- Block list management
- Privacy controls: who can share with you (anyone, contacts only, none)

### 16.7 Settings Integration

**Files:**

- Update `Views/SettingsView.swift` - Add Sharing section
- Account management (sign up, sign in, sign out)
- Username display and edit
- Privacy settings (public profile, who can share)
- Notification preferences
- Blocked users list
- Share history and received clips access

## Phase 17: Polish & Performance (Days 31-33)

### 17.1 Performance Optimization

- Profile with Instruments
- Optimize database queries (add indexes, batch operations)
- Reduce memory footprint (<200MB idle target)
- Optimize embedding generation (batch, cache)
- Lazy loading for large histories

### 17.2 UI Polish

- Refine animations and transitions
- Improve accessibility (VoiceOver support)
- Dark mode support
- Localization preparation (string externalization)

### 17.3 Testing & Quality

**Files:**

- `Tests/` - Unit tests for core services
- `Tests/` - Integration tests for clipboard monitoring
- UI tests for critical workflows
- Performance tests for search, sync, sharing

### 17.4 Distribution Preparation

- Configure code signing
- Set up notarization workflow
- Create DMG installer
- Prepare TestFlight build (if applicable)
- Update README with build instructions

## Technical Decisions

1. **Storage**: Use SQLite (via SQLite.swift or raw SQLite) for flexibility and performance
2. **Daemon Architecture**: XPC service for IPC between UI and background daemon
3. **AI Strategy**: Local-first with Core ML embeddings, optional Cloudflare AI for advanced features
4. **Sync**: CloudKit for iCloud sync with encryption for sensitive items
5. **Permissions**: Request Accessibility and Full Disk Access on first launch with clear explanations
6. **Sharing**: REST API backend service for clip sharing (separate from app, can use Cloudflare Workers, AWS Lambda, or dedicated server). Opt-in user accounts with unique "clippy" usernames. End-to-end encryption optional for sensitive clips.

## Key Files to Create

**Models (7 files):**

- ClipboardItem.swift, SnippetMetadata.swift, Workspace.swift, SyncState.swift, Preferences.swift, User.swift, SharedClip.swift

**Services (20+ files):**

- DatabaseService.swift, ClipboardMonitor.swift, MetadataExtractor.swift, SearchService.swift, MultiPasteService.swift, WorkspaceService.swift, LocalRAGService.swift, CloudflareAIService.swift, AIService.swift, AITaggingService.swift, AIToolService.swift, DeveloperService.swift, DeduplicationService.swift, iCloudSyncService.swift, SmartTaggingService.swift, SummarizationService.swift, SecurityService.swift, PreferencesService.swift, HotkeyService.swift, Logger.swift, AuthenticationService.swift, UserService.swift, ClipSharingService.swift, NotificationService.swift

**Views (8+ files):**

- MenuBarView.swift, FloatingSearchView.swift, DashboardView.swift, SettingsView.swift, WorkspaceManagerView.swift, PreviewComponents.swift, ShareClipView.swift, ReceivedClipsView.swift

**Daemon (3 files):**

- main.swift, IPCServer.swift, CleanupManager.swift

**CLI & Utilities (3 files):**

- clipmind.swift, AppleScriptBridge.swift, Extensions.swift

**Configuration:**

- Info.plist, Entitlements.entitlements, project.pbxproj updates

## Success Criteria

- Clipboard capture latency <200ms
- Semantic search relevance ≥85%
- Memory usage <200MB idle
- Multi-paste reliability 100%
- Crash-free runtime 99% over 24h
- Clip sharing delivery <5s (end-to-end)
- Username lookup/autocomplete <500ms
- All core features functional
- All future enhancements implemented
- Ready for beta distribution