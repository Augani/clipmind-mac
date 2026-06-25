//
//  ClipboardStore.swift
//  clipmind
//
//  Manages clipboard history state and coordinates with ClipboardMonitor
//

import SwiftUI
import Combine

/// Central store for clipboard items
class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var recentItems: [ClipboardItem] = []
    @Published private(set) var hasMoreItems = true
    @Published private(set) var totalItemCount = 0
    @Published var lastCaptured: ClipboardItem?
    @Published var workspaceService = WorkspaceService()

    private let clipboardMonitor: ClipboardMonitor
    private let database = DatabaseService.shared
    private let maxItems: Int = 1000
    private let maxRecentItems: Int = 8
    private let pageSize = 50
    private var currentOffset = 0
    private var isLoadingMore = false

    private var recentContentHashes: Set<Int> = []
    private let maxRecentHashes = 20

    init() {
        self.clipboardMonitor = ClipboardMonitor()
        setupMonitoring()
        loadFromDatabase()
    }

    private func setupMonitoring() {
        clipboardMonitor.onNewClipboardItem = { [weak self] item in
            self?.addItem(item)
        }

        ClipboardManager.shared.onBeforeCopy = { [weak self] in
            self?.clipboardMonitor.markNextChangeAsOurs()
        }
    }

    /// Start monitoring clipboard
    func startMonitoring() {
        clipboardMonitor.startMonitoring()
    }

    /// Stop monitoring clipboard
    func stopMonitoring() {
        clipboardMonitor.stopMonitoring()
    }

    func copyItemToClipboard(_ item: ClipboardItem) {
        if let fullItem = database.fetchFullClipboardItem(id: item.id) {
            ClipboardManager.shared.copyToClipboard(fullItem)
        } else {
            ClipboardManager.shared.copyToClipboard(item)
        }
    }

    /// Add a new clipboard item
    private func addItem(_ item: ClipboardItem) {
        // Check if in incognito mode
        if SecurityService.shared.isIncognitoMode {
            return
        }

        // Check if app is excluded
        if SecurityService.shared.isAppExcluded(item.sourceBundleIdentifier) {
            return
        }

        let contentHash = item.previewText.hashValue
        let isDuplicate = recentContentHashes.contains(contentHash)

        if !isDuplicate {
            recentContentHashes.insert(contentHash)
            if recentContentHashes.count > maxRecentHashes {
                recentContentHashes.remove(recentContentHashes.first!)
            }
            // Apply smart tagging (includes auto-assign workspace and rules)
            var taggedItem = SmartTaggingService.shared.smartTag(item, workspaceService: workspaceService)

            // Fallback to manual workspace assignment if smart tagging didn't assign
            if taggedItem.workspaceId == nil {
                let assignedWorkspaceId = workspaceService.autoAssignWorkspace(for: item)
                taggedItem.workspaceId = assignedWorkspaceId
            }

            var itemWithWorkspace = taggedItem

            // Show toast notification if item was auto-assigned to a non-default workspace
            if let workspaceId = itemWithWorkspace.workspaceId,
               workspaceId != Workspace.uncategorized.id,
               let workspace = workspaceService.workspace(withId: workspaceId) {
                DispatchQueue.main.async {
                    ToastManager.shared.info("Item auto-assigned to '\(workspace.name)'", duration: 2.0)
                }
            }

            // Check for sensitive content and encrypt if needed
            if case .text(let text) = item.content {
                let (isSensitive, types) = SecurityService.shared.detectSensitiveContent(text)
                if isSensitive {
                    itemWithWorkspace.isMarkedSensitive = true
                    itemWithWorkspace.sensitiveContentTypes = types

                    // Encrypt sensitive content if enabled
                    if SecurityService.shared.encryptSensitiveItems {
                        if let encryptedData = SecurityService.shared.encryptString(text) {
                            itemWithWorkspace.encryptedContent = encryptedData
                            // Replace content with placeholder for storage
                            itemWithWorkspace = ClipboardItem(
                                id: itemWithWorkspace.id,
                                content: .text("[Encrypted Content]"),
                                type: itemWithWorkspace.type,
                                timestamp: itemWithWorkspace.timestamp,
                                sourceApp: itemWithWorkspace.sourceApp,
                                sourceBundleIdentifier: itemWithWorkspace.sourceBundleIdentifier,
                                windowTitle: itemWithWorkspace.windowTitle,
                                workspaceId: itemWithWorkspace.workspaceId,
                                isMarkedSensitive: true,
                                encryptedContent: encryptedData,
                                sensitiveContentTypes: types
                            )
                        }
                    }

                    // Schedule auto-delete if enabled
                    scheduleAutoDeleteIfNeeded(for: itemWithWorkspace)
                }
            }

            // Save to database
            if database.saveClipboardItem(itemWithWorkspace) {
                // Add to beginning of list
                items.insert(itemWithWorkspace, at: 0)

                // Trim to max items
                if items.count > maxItems {
                    // Remove excess items from memory and database
                    let itemsToRemove = Array(items.dropFirst(maxItems))
                    items = Array(items.prefix(maxItems))

                    // Delete from database
                    for oldItem in itemsToRemove {
                        _ = database.deleteClipboardItem(oldItem.id)
                    }
                }

                // Update recent items
                updateRecentItems()

                lastCaptured = itemWithWorkspace
            }
        }
    }

    /// Schedule auto-delete for sensitive items
    private func scheduleAutoDeleteIfNeeded(for item: ClipboardItem) {
        let hours = SecurityService.shared.autoDeleteSensitiveHours
        guard hours > 0 else { return }

        let delay = TimeInterval(hours * 3600)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.deleteItem(item)
        }
    }

    /// Update recent items list (top 5)
    private func updateRecentItems() {
        recentItems = Array(items.prefix(maxRecentItems))
    }

    /// Get items filtered by type
    func items(ofType type: ClipboardItemType) -> [ClipboardItem] {
        items.filter { $0.type == type }
    }

    func searchDatabase(
        query: String?,
        filter: SearchFilter = SearchFilter(),
        options: SearchOptions = SearchOptions()
    ) async -> [SearchResult] {
        let dbItems = database.searchClipboardItems(
            query: query,
            types: filter.types,
            workspaceIds: filter.workspaceIds,
            dateStart: filter.dateRange?.start,
            dateEnd: filter.dateRange?.end,
            sensitiveOnly: filter.isSensitiveOnly,
            limit: options.maxResults
        )

        var searchFilter = filter
        searchFilter.query = query ?? ""
        return await SearchService.shared.search(
            items: dbItems,
            filter: searchFilter,
            options: options,
            workspaces: workspaceService.workspaces
        )
    }

    func search(_ query: String) -> [ClipboardItem] {
        searchInItems(query, items: items)
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

    /// Get items filtered by workspace
    func items(forWorkspace workspaceId: UUID?) -> [ClipboardItem] {
        items.filter { $0.workspaceId == workspaceId }
    }

    /// Manually assign workspace to an item
    func assignWorkspace(_ workspaceId: UUID?, to item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        // Update in database
        _ = database.updateClipboardItemWorkspace(item.id, workspaceId: workspaceId)

        // Update in memory
        items[index].workspaceId = workspaceId
    }

    /// Delete an item
    func deleteItem(_ item: ClipboardItem) {
        // Delete from database
        if database.deleteClipboardItem(item.id) {
            // Remove from memory
            items.removeAll { $0.id == item.id }
            updateRecentItems()
        }
    }

    /// Clear all items
    func clearAll() {
        // Clear database
        _ = database.clearAllClipboardItems()

        // Clear memory
        items.removeAll()
        recentItems.removeAll()
    }

    func loadMoreItems() {
        guard hasMoreItems, !isLoadingMore else { return }
        isLoadingMore = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let newItems = self.database.fetchClipboardItemPreviews(
                limit: self.pageSize,
                offset: self.currentOffset
            )

            DispatchQueue.main.async {
                self.items.append(contentsOf: newItems)
                self.currentOffset += newItems.count
                self.hasMoreItems = newItems.count == self.pageSize
                self.isLoadingMore = false
            }
        }
    }

    func loadFullItem(id: UUID) -> ClipboardItem? {
        database.fetchFullClipboardItem(id: id)
    }

    private func loadFromDatabase() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            self.purgeExpiredItemsIfEnabled()
            let totalCount = self.database.getClipboardItemCount()
            let loadedItems = self.database.fetchClipboardItemPreviews(limit: self.pageSize, offset: 0)

            DispatchQueue.main.async {
                self.items = loadedItems
                self.totalItemCount = totalCount
                self.currentOffset = loadedItems.count
                self.hasMoreItems = loadedItems.count < totalCount
                self.updateRecentItems()
                for item in loadedItems.prefix(self.maxRecentHashes) {
                    self.recentContentHashes.insert(item.previewText.hashValue)
                }
            }
        }
    }

    private func purgeExpiredItemsIfEnabled() {
        guard UserDefaults.standard.bool(forKey: "autoDeleteEnabled") else { return }
        let days = max(1, (UserDefaults.standard.object(forKey: "autoDeleteDays") as? Int) ?? 30)
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSince1970
        _ = database.deleteClipboardItems(olderThan: cutoff)
    }
}
