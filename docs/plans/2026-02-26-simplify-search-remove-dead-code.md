# ClipMind Simplification: Remove Dead Code & Fix Search

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove all AI/semantic search, sharing/account features, and unused services. Wire up keyword search with filters as the primary search experience.

**Architecture:** Strip the app to its core: clipboard capture → SQLite storage → keyword search with relevance scoring → filter by type/app/date/workspace. SearchService (existing, keyword-only) becomes the single search path. ClipboardStore delegates to it.

**Tech Stack:** SwiftUI, SQLite3, macOS 14+

---

### Task 1: Delete AI Service Files

**Files:**
- Delete: `clipmind/Services/AI/EmbeddingsService.swift`
- Delete: `clipmind/Services/AI/CoreMLEmbeddingsService.swift`
- Delete: `clipmind/Services/AI/HybridEmbeddingsService.swift`
- Delete: `clipmind/Services/AI/BERTTokenizer.swift`
- Delete: `clipmind/Services/AI/VectorSearchService.swift`
- Delete: `clipmind/Services/EmbeddingGenerationService.swift`

**Step 1: Delete the files**

```bash
rm clipmind/Services/AI/EmbeddingsService.swift
rm clipmind/Services/AI/CoreMLEmbeddingsService.swift
rm clipmind/Services/AI/HybridEmbeddingsService.swift
rm clipmind/Services/AI/BERTTokenizer.swift
rm clipmind/Services/AI/VectorSearchService.swift
rm clipmind/Services/EmbeddingGenerationService.swift
```

**Step 2: Delete the AI directory if empty**

```bash
rmdir clipmind/Services/AI/ 2>/dev/null || echo "Directory not empty, check remaining files"
```

**Step 3: Commit**

```bash
git add -A clipmind/Services/AI/ clipmind/Services/EmbeddingGenerationService.swift
git commit -m "refactor: remove AI embedding and vector search services"
```

---

### Task 2: Delete Search Services (Memory Search, Query Parser)

**Files:**
- Delete: `clipmind/Services/Search/MemorySearchService.swift`
- Delete: `clipmind/Services/Search/NaturalLanguageQueryParser.swift`

**Step 1: Delete the files**

```bash
rm clipmind/Services/Search/MemorySearchService.swift
rm clipmind/Services/Search/NaturalLanguageQueryParser.swift
rmdir clipmind/Services/Search/ 2>/dev/null || echo "Directory not empty"
```

**Step 2: Commit**

```bash
git add -A clipmind/Services/Search/
git commit -m "refactor: remove memory search and query parser services"
```

---

### Task 3: Delete Sharing/Account Services and Models

**Files:**
- Delete: `clipmind/Services/AuthenticationService.swift`
- Delete: `clipmind/Services/ClipSharingService.swift`
- Delete: `clipmind/Models/User.swift`
- Delete: `clipmind/Models/SharedClip.swift`
- Delete: `clipmind/Views/Sharing/ShareClipView.swift`
- Delete: `clipmind/Views/Sharing/ReceivedClipsView.swift`
- Delete: `clipmind/Views/Sharing/AccountDashboardView.swift`
- Delete: `clipmind/Views/Settings/SharingSettingsView.swift`

**Step 1: Delete the files**

```bash
rm clipmind/Services/AuthenticationService.swift
rm clipmind/Services/ClipSharingService.swift
rm clipmind/Models/User.swift
rm clipmind/Models/SharedClip.swift
rm clipmind/Views/Sharing/ShareClipView.swift
rm clipmind/Views/Sharing/ReceivedClipsView.swift
rm clipmind/Views/Sharing/AccountDashboardView.swift
rm clipmind/Views/Settings/SharingSettingsView.swift
rmdir clipmind/Views/Sharing/ 2>/dev/null || echo "Directory not empty"
```

**Step 2: Commit**

```bash
git add -A clipmind/Services/AuthenticationService.swift clipmind/Services/ClipSharingService.swift clipmind/Models/User.swift clipmind/Models/SharedClip.swift clipmind/Views/Sharing/ clipmind/Views/Settings/SharingSettingsView.swift
git commit -m "refactor: remove sharing, account, and authentication features"
```

---

### Task 4: Delete Other Unused Services

**Files:**
- Delete: `clipmind/Services/SummarizationService.swift`
- Delete: `clipmind/Services/URLMetadataService.swift`
- Delete: `clipmind/Services/DeduplicationService.swift`
- Delete: `clipmind/Views/Components/EmbeddingProgressBanner.swift`

**Step 1: Delete the files**

```bash
rm clipmind/Services/SummarizationService.swift
rm clipmind/Services/URLMetadataService.swift
rm clipmind/Services/DeduplicationService.swift
rm clipmind/Views/Components/EmbeddingProgressBanner.swift
```

**Step 2: Commit**

```bash
git add -A clipmind/Services/SummarizationService.swift clipmind/Services/URLMetadataService.swift clipmind/Services/DeduplicationService.swift clipmind/Views/Components/EmbeddingProgressBanner.swift
git commit -m "refactor: remove summarization, URL metadata, deduplication services and embedding banner"
```

---

### Task 5: Clean Up NotificationService (Remove Sharing References)

**Files:**
- Modify: `clipmind/Services/NotificationService.swift`

The entire NotificationService exists to serve sharing notifications via WebSocket. With sharing removed, this service is dead code.

**Step 1: Delete NotificationService**

```bash
rm clipmind/Services/NotificationService.swift
```

**Step 2: Grep for any remaining references**

```bash
grep -r "NotificationService" clipmind/ --include="*.swift" -l
```

Remove any imports or references found.

**Step 3: Commit**

```bash
git add -A clipmind/Services/NotificationService.swift
git commit -m "refactor: remove notification service (sharing-only)"
```

---

### Task 6: Clean Up MemoryManager (Remove AI References)

**Files:**
- Modify: `clipmind/Services/MemoryManager.swift:53-61`

**Step 1: Remove AI service references from optimizeMemoryUsage()**

In `MemoryManager.swift`, the `optimizeMemoryUsage()` method references `EmbeddingsService.shared.clearCache()` and `VectorSearchService.shared.clearCache()`. Remove those two lines. Keep the URLCache and database optimize calls.

Replace the method body:
```swift
func optimizeMemoryUsage() {
    URLCache.shared.removeAllCachedResponses()
    DatabaseService.shared.optimizeDatabase()
}
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add clipmind/Services/MemoryManager.swift
git commit -m "refactor: remove AI service references from MemoryManager"
```

---

### Task 7: Clean Up RichContentPreview (Remove URLMetadataService)

**Files:**
- Modify: `clipmind/Views/Components/RichContentPreview.swift`

**Step 1: Remove URLMetadataService reference**

Remove the `private let urlMetadataService = URLMetadataService.shared` property and the `@State private var urlMetadata: URLMetadata?` state. Replace any URL metadata display code with simple URL text display. The `URLMetadata` type is defined in `URLMetadataService.swift` which we deleted, so any references to it must go.

Search the file for all uses of `urlMetadataService` and `urlMetadata` and `URLMetadata` and remove/replace them.

**Step 2: Build to verify**

```bash
xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add clipmind/Views/Components/RichContentPreview.swift
git commit -m "refactor: remove URL metadata service dependency from RichContentPreview"
```

---

### Task 8: Clean Up ClipboardMenuPopover (Remove Sharing)

**Files:**
- Modify: `clipmind/Views/MenuBar/ClipboardMenuPopover.swift`

**Step 1: Remove sharing references**

Remove these lines/properties:
- `@StateObject private var sharingService = ClipSharingService.shared` (line 13)
- `@StateObject private var authService = AuthenticationService.shared` (line 14)
- `@State private var showReceivedClips = false` (line 19)
- `@State private var showShareView = false` (line 20)
- `@State private var showAccountDashboard = false` (line 21)
- `@State private var itemToShare: ClipboardItem?` (line 22)
- The `.sheet(isPresented: $showReceivedClips)` block (lines 87-89)
- The `.sheet(isPresented: $showShareView)` block (lines 91-105)
- The `.sheet(isPresented: $showAccountDashboard)` block (lines 106-108)
- The account/social button in the header (lines 130-159 — the `if authService.isAuthenticated` block)
- The share context menu item in itemsList (lines 193-199 — the `if authService.isAuthenticated` block)

**Step 2: Build to verify**

```bash
xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add clipmind/Views/MenuBar/ClipboardMenuPopover.swift
git commit -m "refactor: remove sharing UI from ClipboardMenuPopover"
```

---

### Task 9: Clean Up MenuBarView (Remove Sharing)

**Files:**
- Modify: `clipmind/Views/MenuBar/MenuBarView.swift:132`

**Step 1: Remove sharing references**

Remove `@StateObject private var sharingService = ClipSharingService.shared` and any UI that references it.

**Step 2: Commit**

```bash
git add clipmind/Views/MenuBar/MenuBarView.swift
git commit -m "refactor: remove sharing reference from MenuBarView"
```

---

### Task 10: Clean Up DashboardView (Remove AI, Sharing, Summarization)

**Files:**
- Modify: `clipmind/Views/Dashboard/DashboardView.swift`

**Step 1: Remove dead service references**

Remove these properties:
- `@StateObject private var embeddingService = EmbeddingGenerationService.shared` (line 27)
- `@StateObject private var summarizationService = SummarizationService.shared` (line 29)
- `@State private var showingSummary = false` (line 30)
- `@State private var currentSummary: ClipboardSummary?` (line 31)
- `@State private var showingShareView = false` (line 32)
- `@State private var itemToShare: ClipboardItem?` (line 33)
- `@State private var showingAccountDashboard = false` (line 34)
- `@StateObject private var authService = AuthenticationService.shared` (line 35)

**Step 2: Remove sharing/summarization UI**

Remove:
- The `.sheet(isPresented: $showingSummary)` block (lines 137-141)
- The `.sheet(isPresented: $showingShareView)` block (lines 142-156)
- The `.sheet(isPresented: $showingAccountDashboard)` block (lines 157-159)
- The "Summarize" toolbar item (lines 240-251)
- The "Social" toolbar item (lines 259-264)
- The `generateSummary()` method (lines 757-780)
- All `authService.isAuthenticated` checks in context menus (grid view lines 549-558, compact view lines 592-601)
- All `itemToShare` / `showingShareView` references in context menus

**Step 3: Build to verify**

```bash
xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5
```

**Step 4: Commit**

```bash
git add clipmind/Views/Dashboard/DashboardView.swift
git commit -m "refactor: remove AI, sharing, and summarization from DashboardView"
```

---

### Task 11: Clean Up ClipboardItemDetailView (Remove Summarization)

**Files:**
- Modify: `clipmind/Views/Dashboard/ClipboardItemDetailView.swift`

**Step 1: Remove summarization references**

Remove:
- `@StateObject private var summarizationService = SummarizationService.shared` (line 15)
- `@State private var showingSummary = false` (line 16)
- `@State private var currentSummary: ClipboardSummary?` (line 17)
- Any summarize buttons or summary display UI
- The `ClipboardSummary` type reference (defined in SummarizationService which is deleted)

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add clipmind/Views/Dashboard/ClipboardItemDetailView.swift
git commit -m "refactor: remove summarization from ClipboardItemDetailView"
```

---

### Task 12: Clean Up AdvancedSearchView (Remove AI Search Modes)

**Files:**
- Modify: `clipmind/Views/Search/AdvancedSearchView.swift`

**Step 1: Remove AI search references**

Remove:
- `private let vectorSearchService = VectorSearchService.shared` (line 13)
- `private let memorySearchService = MemorySearchService.shared` (line 14)
- `private let queryParser = NaturalLanguageQueryParser.shared` (line 15)
- `@State private var vectorResults: [VectorSearchResult] = []` (line 21)
- `@State private var memoryResults: [MemorySearchResult] = []` (line 22)
- `@State private var searchMode: SearchMode = .hybrid` (line 23)
- `@State private var isContextualQuery = false` (line 28)
- Any search mode picker/toggle UI
- Any vector/memory search execution code
- References to `VectorSearchResult`, `MemorySearchResult`, `SearchMode`, `ParsedQuery`

Keep the `SearchService` integration — this is the keyword search we want. Keep all filter UI (type, app, date, workspace filters). The view should use `SearchService.search()` exclusively.

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add clipmind/Views/Search/AdvancedSearchView.swift
git commit -m "refactor: simplify AdvancedSearchView to keyword search only"
```

---

### Task 13: Clean Up FloatingSearchView (Remove AI References)

**Files:**
- Modify: `clipmind/Views/FloatingSearchView.swift`

**Step 1: Remove dead references**

Remove:
- `private let memorySearch = MemorySearchService.shared` (line 23)
- `private let queryParser = NaturalLanguageQueryParser.shared` (line 24)

**Step 2: Simplify filteredItems**

The `filteredItems` computed property currently has a branch for `queryParser.hasContextualPatterns()` (lines 49-57). Replace the entire search logic with a call through `clipboardStore.search()` (which we'll wire to SearchService in Task 16).

Replace lines 48-57:
```swift
if !searchText.isEmpty {
    items = clipboardStore.searchInItems(searchText, items: items)
}
```

This removes the contextual pattern parsing that relied on `NaturalLanguageQueryParser` and the `applyParsedFilters` method.

**Step 3: Remove the applyParsedFilters method**

Delete the `applyParsedFilters(_:parsed:)` method (lines 83-130) and the `isBrowserBundle`/`isCodeEditorBundle` helper methods (lines 132-140) since they reference `ParsedQuery` types from the deleted query parser.

**Step 4: Build to verify**

**Step 5: Commit**

```bash
git add clipmind/Views/FloatingSearchView.swift
git commit -m "refactor: remove AI search references from FloatingSearchView"
```

---

### Task 14: Clean Up SettingsView (Remove Sharing Tab)

**Files:**
- Modify: `clipmind/Views/Settings/SettingsView.swift`

**Step 1: Remove the Sharing tab**

Remove the `SharingSettingsView` tab item (lines 53-58):
```swift
SharingSettingsView()
    .tabItem {
        Label("Sharing & Account", systemImage: "person.2")
    }
    .tag(6)
```

Renumber subsequent tags (iCloud Sync → 6, Auto-Tagging → 7, About → 8).

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add clipmind/Views/Settings/SettingsView.swift
git commit -m "refactor: remove sharing settings tab"
```

---

### Task 15: Clean Up CleanupSettingsView (Remove DeduplicationService)

**Files:**
- Modify: `clipmind/Views/Settings/CleanupSettingsView.swift`

**Step 1: Remove deduplication references**

Remove `@StateObject private var deduplicationService = DeduplicationService.shared` and any UI that references it (dedup scan buttons, dedup results, etc.). The cleanup view should keep its auto-cleanup schedule settings but remove the dedup-specific features.

Grep the file for all `deduplicationService` and `DeduplicationService` references and remove them.

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add clipmind/Views/Settings/CleanupSettingsView.swift
git commit -m "refactor: remove deduplication UI from CleanupSettingsView"
```

---

### Task 16: Clean Up DatabaseService (Remove Embedding & Sharing)

**Files:**
- Modify: `clipmind/Services/DatabaseService.swift`

**Step 1: Remove embedding methods**

Search for and remove:
- `addEmbeddingsColumnIfNeeded()` method and its call in `createTables()`
- `saveEmbedding()` method
- `loadEmbedding()` method
- `getItemsWithoutEmbeddings()` method
- The `CREATE INDEX ... idx_embedding_exists` line
- Any other embedding-related methods

**Step 2: Remove sharing table creation**

Remove:
- `createSharingTablesIfNeeded()` method and its call in `createTables()`
- All sharing-related CRUD methods (save/fetch/update/delete for sharing_users, shared_clips, user_contacts, share_settings, share_notifications)

**Step 3: Build to verify**

**Step 4: Commit**

```bash
git add clipmind/Services/DatabaseService.swift
git commit -m "refactor: remove embedding and sharing code from DatabaseService"
```

---

### Task 17: Update Xcode Project File

**Files:**
- Modify: `clipmind.xcodeproj/project.pbxproj`

**Step 1: Remove deleted file references from Xcode project**

The Xcode project file references all deleted files. Remove the PBXFileReference, PBXBuildFile, and PBXGroup entries for every deleted file. This is the list:

- `EmbeddingsService.swift`
- `CoreMLEmbeddingsService.swift`
- `HybridEmbeddingsService.swift`
- `BERTTokenizer.swift`
- `VectorSearchService.swift`
- `EmbeddingGenerationService.swift`
- `MemorySearchService.swift`
- `NaturalLanguageQueryParser.swift`
- `AuthenticationService.swift`
- `ClipSharingService.swift`
- `User.swift`
- `SharedClip.swift`
- `ShareClipView.swift`
- `ReceivedClipsView.swift`
- `AccountDashboardView.swift`
- `SharingSettingsView.swift`
- `SummarizationService.swift`
- `URLMetadataService.swift`
- `DeduplicationService.swift`
- `EmbeddingProgressBanner.swift`
- `NotificationService.swift`

Also remove the `AI` and `Sharing` group entries if they become empty.

**Step 2: Build to verify everything compiles**

```bash
xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add clipmind.xcodeproj/project.pbxproj
git commit -m "refactor: remove deleted files from Xcode project"
```

---

### Task 18: Full Build Verification After Cleanup

**Step 1: Do a clean build**

```bash
xcodebuild clean -scheme clipmind && xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -30
```

**Step 2: Fix any remaining compilation errors**

Grep for any remaining references to deleted types:
```bash
grep -rn "EmbeddingsService\|VectorSearchService\|MemorySearchService\|NaturalLanguageQueryParser\|SummarizationService\|AuthenticationService\|ClipSharingService\|URLMetadataService\|DeduplicationService\|EmbeddingGenerationService\|EmbeddingProgressBanner\|BERTTokenizer\|CoreMLEmbeddingsService\|HybridEmbeddingsService\|ClipboardSummary\|VectorSearchResult\|MemorySearchResult\|SearchMode\|ParsedQuery\|ShareNotification\|URLMetadata\|NotificationService" clipmind/ --include="*.swift"
```

Fix any found references.

**Step 3: Commit any remaining fixes**

```bash
git add -A
git commit -m "fix: resolve remaining compilation errors after cleanup"
```

---

## Phase 2: Fix Core Flow

---

### Task 19: Wire SearchService Into ClipboardStore

**Files:**
- Modify: `clipmind/Services/ClipboardStore.swift:172-185`

**Step 1: Replace the simple search with SearchService**

Replace the current `search()` and `searchInItems()` methods:

```swift
func search(
    _ query: String,
    filter: SearchFilter = SearchFilter(),
    options: SearchOptions = SearchOptions()
) async -> [SearchResult] {
    var searchFilter = filter
    searchFilter.query = query
    return await SearchService.shared.search(
        items: items,
        filter: searchFilter,
        options: options,
        workspaces: workspaceService.workspaces
    )
}

func searchInItems(_ query: String, items: [ClipboardItem]) -> [ClipboardItem] {
    guard !query.isEmpty else { return items }
    let lowercasedQuery = query.lowercased()
    return items.filter { item in
        item.previewText.lowercased().contains(lowercasedQuery) ||
        item.sourceApp.lowercased().contains(lowercasedQuery) ||
        (item.windowTitle?.lowercased().contains(lowercasedQuery) ?? false)
    }
}
```

Keep `searchInItems` as a synchronous fallback for simple filtering (used in FloatingSearchView). Add the new async `search()` that delegates to `SearchService` with full scoring and filtering.

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add clipmind/Services/ClipboardStore.swift
git commit -m "feat: wire SearchService into ClipboardStore for scored search"
```

---

### Task 20: Update DashboardView to Use SearchService

**Files:**
- Modify: `clipmind/Views/Dashboard/DashboardView.swift`

**Step 1: Update filteredItems to use SearchService**

The current `filteredItems` computed property (lines 55-88) does simple substring search and manual sorting. Replace it with async search using SearchService.

Add state for search results:
```swift
@State private var searchResults: [SearchResult] = []
@State private var isSearching = false
```

Add a search trigger method:
```swift
private func performSearch() {
    let query = searchText
    let typeFilter = selectedFilter
    let workspaceFilter = selectedWorkspace

    Task {
        isSearching = true
        var filter = SearchFilter()
        filter.query = query
        if let type = typeFilter {
            filter.types = [type]
        }
        if let workspaceId = workspaceFilter {
            filter.workspaceIds = [workspaceId]
        }

        var options = SearchOptions()
        options.sortBy = sortOptionToSearchSort(sortOption)

        let results = await clipboardStore.search(
            query,
            filter: filter,
            options: options
        )

        await MainActor.run {
            searchResults = results
            isSearching = false
        }
    }
}
```

Update `filteredItems` to return items from `searchResults` when searching, or plain items when browsing:
```swift
var filteredItems: [ClipboardItem] {
    if !searchText.isEmpty || selectedFilter != nil || selectedWorkspace != nil {
        return searchResults.map { $0.item }
    }

    var items = clipboardStore.items
    switch sortOption {
    case .dateNewest: items.sort { $0.timestamp > $1.timestamp }
    case .dateOldest: items.sort { $0.timestamp < $1.timestamp }
    case .type: items.sort { $0.type.rawValue < $1.type.rawValue }
    case .sourceApp: items.sort { $0.sourceApp < $1.sourceApp }
    case .contentLength: items.sort { $0.previewText.count > $1.previewText.count }
    }
    return items
}
```

Add `.onChange(of: searchText)`, `.onChange(of: selectedFilter)`, `.onChange(of: selectedWorkspace)`, `.onChange(of: sortOption)` modifiers to trigger `performSearch()`.

Add a helper to map DashboardView's SortOption to SearchSortOrder:
```swift
private func sortOptionToSearchSort(_ option: SortOption) -> SearchSortOrder {
    switch option {
    case .dateNewest: return .dateNewest
    case .dateOldest: return .dateOldest
    case .type: return .type
    case .sourceApp: return .sourceApp
    case .contentLength: return .relevance
    }
}
```

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add clipmind/Views/Dashboard/DashboardView.swift
git commit -m "feat: connect DashboardView search to SearchService with filters"
```

---

### Task 21: Update FloatingSearchView to Use Better Search

**Files:**
- Modify: `clipmind/Views/FloatingSearchView.swift`

**Step 1: Verify the current simple search works**

FloatingSearchView currently uses `clipboardStore.searchInItems()` (synchronous substring match) with manual time/app/type filters applied. This is actually fine for the floating search — it needs to be fast and synchronous since it updates on every keystroke.

Verify that after the cleanup in Task 13, the view compiles and the filter flow works:
- Time filters (today, yesterday, this week, morning, afternoon, evening) applied first
- Source app filter applied second
- Content type filter applied third
- Text search applied last via `clipboardStore.searchInItems()`

The floating search should remain synchronous for responsiveness. No changes needed beyond the cleanup already done in Task 13.

**Step 2: Build to verify**

```bash
xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5
```

**Step 3: Commit (if any fixes needed)**

---

### Task 22: Clean Up AdvancedSearchView to Use SearchService Only

**Files:**
- Modify: `clipmind/Views/Search/AdvancedSearchView.swift`

**Step 1: Ensure the view only uses SearchService**

After the cleanup in Task 12, verify that AdvancedSearchView:
- Uses `SearchService.shared.search()` for all searches
- Filter UI for type, app, date, workspace all feed into `SearchFilter`
- Search options (case sensitive, whole word, fuzzy) feed into `SearchOptions`
- Results are displayed from `[SearchResult]`
- No references to vector/memory/contextual search remain

**Step 2: Build to verify**

**Step 3: Commit (if any fixes needed)**

---

### Task 23: Final Build and End-to-End Verification

**Step 1: Clean build**

```bash
xcodebuild clean -scheme clipmind && xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED with 0 errors

**Step 2: Grep for any orphaned references**

```bash
grep -rn "embedding\|Embedding\|semantic\|Semantic\|vector\|Vector.*Search\|sharing\|Sharing.*Service\|AuthenticationService\|ClipSharingService\|SummarizationService\|URLMetadataService\|DeduplicationService\|NotificationService\|ParsedQuery\|MemorySearch\|NaturalLanguageQuery" clipmind/ --include="*.swift" | grep -v "// " | grep -v ".build/"
```

Fix any remaining orphans.

**Step 3: Verify the complete flow works**

Manually verify (or review code paths for):
1. App launches as menu bar app
2. Clipboard monitoring starts
3. New copies are captured, tagged, stored in SQLite
4. Menu bar popover shows recent items
5. Clicking an item copies it back
6. Dashboard opens with sidebar filters (type, workspace)
7. Search bar searches via SearchService with relevance scoring
8. Floating search (⌘+Shift+V) opens with filter chips and text search
9. Settings opens without sharing tab

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete ClipMind simplification - keyword search with filters"
```

---

## Summary of Changes

**Deleted (21 files):**
- 5 AI services (EmbeddingsService, CoreMLEmbeddingsService, HybridEmbeddingsService, BERTTokenizer, VectorSearchService)
- 1 embedding generation service
- 2 search services (MemorySearchService, NaturalLanguageQueryParser)
- 2 sharing services (AuthenticationService, ClipSharingService)
- 1 notification service
- 3 unused services (SummarizationService, URLMetadataService, DeduplicationService)
- 2 sharing models (User, SharedClip)
- 3 sharing views (ShareClipView, ReceivedClipsView, AccountDashboardView)
- 1 settings view (SharingSettingsView)
- 1 UI component (EmbeddingProgressBanner)

**Modified (~10 files):**
- ClipboardStore: Wire SearchService for async scored search
- DashboardView: Remove AI/sharing, connect SearchService
- FloatingSearchView: Remove AI references, keep simple search
- AdvancedSearchView: Remove AI modes, keep keyword search
- ClipboardMenuPopover: Remove sharing UI
- MenuBarView: Remove sharing reference
- ClipboardItemDetailView: Remove summarization
- SettingsView: Remove sharing tab
- CleanupSettingsView: Remove dedup UI
- DatabaseService: Remove embedding/sharing tables
- MemoryManager: Remove AI cache clearing
- RichContentPreview: Remove URLMetadataService
- Xcode project file: Remove deleted file references

**Kept intact:**
- SmartTaggingService (regex-based auto-tagging)
- SearchService (keyword search with scoring — now the primary search)
- All clipboard capture/monitor/store logic
- Workspace management
- Security/encryption
- Settings (general, hotkeys, security, multi-paste, cleanup, iCloud, auto-tagging, about)
