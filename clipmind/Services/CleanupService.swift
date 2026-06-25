//
//  CleanupService.swift
//  clipmind
//
//  Automatic cleanup, archiving, and retention management
//

import Foundation
import Combine

/// Retention policy configuration
struct RetentionPolicy: Codable, Equatable {
    var maxItems: Int = 10000
    var maxDays: Int = 90
    var archiveAfterDays: Int = 30
    var autoDeleteSensitiveAfterHours: Int = 24
    var lowDiskSpaceThresholdMB: Int = 100
    var enableAutoCleanup: Bool = true
}

/// Cleanup statistics
struct CleanupStats {
    var itemsDeleted: Int = 0
    var itemsArchived: Int = 0
    var diskSpaceFreedMB: Double = 0
    var lastCleanupDate: Date?
    var nextScheduledCleanup: Date?
}

/// High-performance cleanup and archiving service
class CleanupService: ObservableObject {
    static let shared = CleanupService()

    @Published var policy: RetentionPolicy
    @Published var stats: CleanupStats = CleanupStats()
    @Published var isRunningCleanup = false

    private let database = DatabaseService.shared
    private var cleanupTimer: Timer?
    private let preferencesKey = "retentionPolicy"

    // Performance: Track items scheduled for deletion
    private var scheduledDeletions: [UUID: Date] = [:]
    private let deletionQueue = DispatchQueue(label: "com.clipmind.cleanup", qos: .background)

    private init() {
        // Load policy from UserDefaults
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let policy = try? JSONDecoder().decode(RetentionPolicy.self, from: data) {
            self.policy = policy
        } else {
            self.policy = RetentionPolicy()
        }

        // Schedule daily cleanup at 3 AM
        scheduleAutomaticCleanup()
    }

    // MARK: - Public API

    /// Run full cleanup process
    func runCleanup() async -> CleanupStats {
        await MainActor.run { isRunningCleanup = true }

        var localStats = CleanupStats()

        // 1. Delete items exceeding max items limit
        let deletedByCount = await deleteExcessItems()
        localStats.itemsDeleted += deletedByCount

        // 2. Delete old items based on retention days
        let deletedByAge = await deleteOldItems()
        localStats.itemsDeleted += deletedByAge

        // 3. Archive items based on archive policy
        let archived = await archiveOldItems()
        localStats.itemsArchived = archived

        // 4. Delete expired sensitive items
        let deletedSensitive = await deleteSensitiveItems()
        localStats.itemsDeleted += deletedSensitive

        // 5. Check disk space and cleanup if needed
        if isDiskSpaceLow() {
            let emergencyDeleted = await emergencyCleanup()
            localStats.itemsDeleted += emergencyDeleted
        }

        // 6. Calculate disk space freed (rough estimate)
        localStats.diskSpaceFreedMB = Double(localStats.itemsDeleted) * 0.01 // ~10KB per item

        // 7. Update stats
        localStats.lastCleanupDate = Date()
        localStats.nextScheduledCleanup = nextScheduledCleanupDate()

        await MainActor.run {
            stats = localStats
            isRunningCleanup = false
        }

        // Show toast notification
        if localStats.itemsDeleted > 0 || localStats.itemsArchived > 0 {
            ToastManager.shared.info(
                "Cleanup complete: \(localStats.itemsDeleted) deleted, \(localStats.itemsArchived) archived",
                duration: 4.0
            )
        }

        return localStats
    }

    /// Schedule an item for deletion after specified hours
    func scheduleForDeletion(item: ClipboardItem, afterHours hours: Int) {
        let deletionDate = Date().addingTimeInterval(TimeInterval(hours * 3600))

        deletionQueue.async {
            self.scheduledDeletions[item.id] = deletionDate
        }

        // Schedule actual deletion
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(hours * 3600)) { [weak self] in
            self?.executeScheduledDeletion(itemId: item.id)
        }
    }

    /// Save policy changes
    func savePolicy(_ newPolicy: RetentionPolicy) {
        policy = newPolicy

        if let data = try? JSONEncoder().encode(newPolicy) {
            UserDefaults.standard.set(data, forKey: preferencesKey)
        }

        // Reschedule cleanup with new policy
        scheduleAutomaticCleanup()

        ToastManager.shared.success("Retention policy updated")
    }

    /// Get items that will be affected by next cleanup
    func getItemsToCleanup() -> (toDelete: [ClipboardItem], toArchive: [ClipboardItem]) {
        let allItems = database.fetchAllClipboardItems()

        // Items to delete (exceeding limits or too old)
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(policy.maxDays * 86400))
        let itemsToDelete = allItems
            .filter { $0.timestamp < cutoffDate }
            .sorted { $0.timestamp < $1.timestamp }

        // Items to archive
        let archiveCutoffDate = Date().addingTimeInterval(-TimeInterval(policy.archiveAfterDays * 86400))
        let itemsToArchive = allItems
            .filter { $0.timestamp < archiveCutoffDate && $0.timestamp >= cutoffDate }
            .sorted { $0.timestamp < $1.timestamp }

        return (itemsToDelete, itemsToArchive)
    }

    // MARK: - Private Cleanup Methods

    /// Delete items exceeding max items limit
    private func deleteExcessItems() async -> Int {
        let allItems = database.fetchAllClipboardItems()

        guard allItems.count > policy.maxItems else { return 0 }

        // Sort by timestamp, delete oldest
        let sortedItems = allItems.sorted { $0.timestamp < $1.timestamp }
        let itemsToDelete = sortedItems.prefix(allItems.count - policy.maxItems)

        var deleted = 0
        for item in itemsToDelete {
            if database.deleteClipboardItem(item.id) {
                deleted += 1
            }
        }

        return deleted
    }

    /// Delete items older than retention period
    private func deleteOldItems() async -> Int {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(policy.maxDays * 86400))
        let allItems = database.fetchAllClipboardItems()

        var deleted = 0
        for item in allItems where item.timestamp < cutoffDate {
            if database.deleteClipboardItem(item.id) {
                deleted += 1
            }
        }

        return deleted
    }

    /// Archive old items (mark as archived, not deleted)
    private func archiveOldItems() async -> Int {
        // Note: Archive functionality requires database schema update
        // For now, we'll just return 0
        // TODO: Add isArchived column to clipboard_items table
        return 0
    }

    /// Delete expired sensitive items
    private func deleteSensitiveItems() async -> Int {
        guard policy.autoDeleteSensitiveAfterHours > 0 else { return 0 }

        let cutoffDate = Date().addingTimeInterval(-TimeInterval(policy.autoDeleteSensitiveAfterHours * 3600))
        let allItems = database.fetchAllClipboardItems()

        var deleted = 0
        for item in allItems where item.isMarkedSensitive && item.timestamp < cutoffDate {
            if database.deleteClipboardItem(item.id) {
                deleted += 1
            }
        }

        return deleted
    }

    /// Emergency cleanup when disk space is low
    private func emergencyCleanup() async -> Int {
        print("⚠️ Emergency cleanup triggered - low disk space")

        // Aggressively delete oldest 20% of items
        let allItems = database.fetchAllClipboardItems()
        let sortedItems = allItems.sorted { $0.timestamp < $1.timestamp }
        let deleteCount = max(100, allItems.count / 5) // Delete at least 100 or 20%
        let itemsToDelete = sortedItems.prefix(deleteCount)

        var deleted = 0
        for item in itemsToDelete {
            if database.deleteClipboardItem(item.id) {
                deleted += 1
            }
        }

        ToastManager.shared.warning("Low disk space - emergency cleanup performed")

        return deleted
    }

    /// Execute a scheduled deletion
    private func executeScheduledDeletion(itemId: UUID) {
        // Check if still scheduled
        var shouldDelete = false
        deletionQueue.sync {
            if let scheduledDate = scheduledDeletions[itemId],
               scheduledDate <= Date() {
                scheduledDeletions.removeValue(forKey: itemId)
                shouldDelete = true
            }
        }

        if shouldDelete {
            _ = database.deleteClipboardItem(itemId)
        }
    }

    // MARK: - Scheduling

    /// Schedule automatic cleanup
    private func scheduleAutomaticCleanup() {
        guard policy.enableAutoCleanup else {
            cleanupTimer?.invalidate()
            cleanupTimer = nil
            return
        }

        cleanupTimer?.invalidate()

        // Schedule daily cleanup at 3 AM
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 3
        components.minute = 0

        guard var nextCleanup = calendar.date(from: components) else { return }

        // If 3 AM has passed today, schedule for tomorrow
        if nextCleanup <= now {
            nextCleanup = calendar.date(byAdding: .day, value: 1, to: nextCleanup) ?? nextCleanup
        }

        let timeInterval = nextCleanup.timeIntervalSince(now)

        // Create timer
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task {
                await self?.runCleanup()
                // Reschedule for next day
                self?.scheduleAutomaticCleanup()
            }
        }

        DispatchQueue.main.async {
            self.stats.nextScheduledCleanup = nextCleanup
        }
    }

    /// Get next scheduled cleanup date
    private func nextScheduledCleanupDate() -> Date {
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 3
        components.minute = 0

        guard var nextCleanup = calendar.date(from: components) else { return now }

        if nextCleanup <= now {
            nextCleanup = calendar.date(byAdding: .day, value: 1, to: nextCleanup) ?? nextCleanup
        }

        return nextCleanup
    }

    // MARK: - Disk Space Management

    /// Check if available disk space is low
    private func isDiskSpaceLow() -> Bool {
        guard let home = FileManager.default.homeDirectoryForCurrentUser.path as NSString? else {
            return false
        }

        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: home as String)
            if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
                let freeSpaceMB = freeSpace.doubleValue / (1024 * 1024)
                return freeSpaceMB < Double(policy.lowDiskSpaceThresholdMB)
            }
        } catch {
            print("Error checking disk space: \(error)")
        }

        return false
    }

    /// Get available disk space in MB
    func getAvailableDiskSpaceMB() -> Double {
        guard let home = FileManager.default.homeDirectoryForCurrentUser.path as NSString? else {
            return 0
        }

        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: home as String)
            if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
                return freeSpace.doubleValue / (1024 * 1024)
            }
        } catch {
            print("Error checking disk space: \(error)")
        }

        return 0
    }

    /// Get database size in MB
    func getDatabaseSizeMB() -> Double {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("ClipMind/clipboard.db").path

        do {
            let attributes = try fileManager.attributesOfItem(atPath: dbPath)
            if let fileSize = attributes[.size] as? NSNumber {
                return fileSize.doubleValue / (1024 * 1024)
            }
        } catch {
            print("Error getting database size: \(error)")
        }

        return 0
    }
}
