//
//  iCloudSyncService.swift
//  clipmind
//
//  iCloud sync service using CloudKit for cross-device synchronization
//

import Foundation
import CloudKit
import Combine
import AppKit

/// Sync state for tracking sync progress
enum SyncState {
    case idle
    case syncing
    case completed
    case failed(Error)
    case paused
}

/// Sync conflict resolution strategy
enum ConflictResolution {
    case keepLocal           // Keep local version
    case keepRemote          // Keep remote version
    case keepBoth            // Keep both versions
    case keepNewest          // Keep version with newest timestamp (default)
    case askUser             // Prompt user to decide
}

/// Sync statistics
struct SyncStats {
    var lastSyncDate: Date?
    var itemsUploaded: Int = 0
    var itemsDownloaded: Int = 0
    var conflictsResolved: Int = 0
    var syncErrors: Int = 0
    var totalSynced: Int {
        itemsUploaded + itemsDownloaded
    }
}

/// Conflict information for user review
struct SyncConflict: Identifiable {
    let id = UUID()
    let localItem: ClipboardItem
    let remoteItem: ClipboardItem
    let recordID: CKRecord.ID
}

/// iCloud sync service using CloudKit
class iCloudSyncService: ObservableObject {
    static let shared = iCloudSyncService()

    @Published var syncState: SyncState = .idle
    @Published var stats: SyncStats = SyncStats()
    @Published var isEnabled: Bool = false
    @Published var conflicts: [SyncConflict] = []
    @Published var syncProgress: Double = 0.0

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordZone: CKRecordZone
    private let database = DatabaseService.shared
    private let securityService = SecurityService.shared

    // Conflict resolution strategy
    var conflictResolution: ConflictResolution = .keepNewest

    // Subscription for real-time updates
    private var subscription: CKQuerySubscription?
    private var cancellables = Set<AnyCancellable>()

    // Change tracking
    private var serverChangeToken: CKServerChangeToken?
    private let changeTokenKey = "iCloudChangeToken"

    private init() {
        // Initialize CloudKit container
        container = CKContainer(identifier: "iCloud.com.clipmind.clipboard")
        privateDatabase = container.privateCloudDatabase

        // Custom zone for atomic operations and change tracking
        recordZone = CKRecordZone(zoneName: "ClipboardZone")

        // Load saved state
        loadSyncState()

        // Setup sync if enabled
        if isEnabled {
            setupSync()
        }
    }

    // MARK: - Public API

    /// Enable iCloud sync
    func enableSync() async throws {
        // Check iCloud account status
        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else {
            throw SyncError.iCloudUnavailable
        }

        // Create custom zone
        try await createCustomZone()

        // Setup subscription for push notifications
        try await setupSubscription()

        await MainActor.run {
            isEnabled = true
            saveSyncState()
        }

        // Perform initial sync
        try await performFullSync()
    }

    /// Disable iCloud sync
    func disableSync() {
        isEnabled = false
        saveSyncState()
        syncState = .idle
    }

    /// Perform manual sync
    func performSync() async throws {
        guard isEnabled else {
            throw SyncError.syncDisabled
        }

        await MainActor.run {
            syncState = .syncing
            syncProgress = 0.0
        }

        do {
            // Fetch remote changes
            try await fetchChanges()

            // Upload local changes
            try await uploadChanges()

            await MainActor.run {
                stats.lastSyncDate = Date()
                syncState = .completed
                syncProgress = 1.0
                saveSyncState()
            }

            ToastManager.shared.success("Sync completed")
        } catch {
            await MainActor.run {
                syncState = .failed(error)
                stats.syncErrors += 1
            }
            throw error
        }
    }

    /// Upload a single clipboard item
    func uploadItem(_ item: ClipboardItem) async throws {
        guard isEnabled else { return }

        let record = try createRecord(from: item)
        try await privateDatabase.save(record)

        await MainActor.run {
            stats.itemsUploaded += 1
        }
    }

    /// Delete an item from iCloud
    func deleteItem(recordID: CKRecord.ID) async throws {
        guard isEnabled else { return }
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    /// Resolve a conflict
    func resolveConflict(_ conflict: SyncConflict, resolution: ConflictResolution) async throws {
        switch resolution {
        case .keepLocal:
            // Upload local version
            try await uploadItem(conflict.localItem)

        case .keepRemote:
            // Keep remote version (delete local, download remote)
            _ = database.deleteClipboardItem(conflict.localItem.id)
            // Remote item is already downloaded

        case .keepBoth:
            // Keep both versions (create new item for remote with new ID)
            let newItem = ClipboardItem(
                content: conflict.remoteItem.content,
                type: conflict.remoteItem.type,
                timestamp: conflict.remoteItem.timestamp,
                sourceApp: conflict.remoteItem.sourceApp,
                windowTitle: conflict.remoteItem.windowTitle,
                workspaceId: conflict.remoteItem.workspaceId,
                isMarkedSensitive: conflict.remoteItem.isMarkedSensitive
            )
            _ = database.saveClipboardItem(newItem)

        case .keepNewest:
            if conflict.localItem.timestamp > conflict.remoteItem.timestamp {
                try await uploadItem(conflict.localItem)
            } else {
                _ = database.deleteClipboardItem(conflict.localItem.id)
            }

        case .askUser:
            // Conflict is already added to conflicts array for user review
            return
        }

        // Remove from conflicts
        await MainActor.run {
            conflicts.removeAll { $0.id == conflict.id }
            stats.conflictsResolved += 1
        }
    }

    // MARK: - Private Methods

    /// Perform full sync (initial or after re-enabling)
    private func performFullSync() async throws {
        await MainActor.run {
            syncState = .syncing
            syncProgress = 0.0
        }

        // Fetch all remote items
        try await fetchChanges()

        // Upload all local items that don't exist remotely
        let localItems = database.fetchAllClipboardItems()
        var uploaded = 0

        for item in localItems {
            // Check if item exists remotely
            let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: recordZone.zoneID)
            do {
                _ = try await privateDatabase.record(for: recordID)
                // Item exists, skip
            } catch {
                // Item doesn't exist, upload
                try await uploadItem(item)
                uploaded += 1
            }

            // Update progress
            let progress = Double(uploaded) / Double(localItems.count)
            await MainActor.run {
                syncProgress = progress
            }
        }

        await MainActor.run {
            stats.lastSyncDate = Date()
            syncState = .completed
            syncProgress = 1.0
        }
    }

    /// Fetch changes from iCloud
    private func fetchChanges() async throws {
        let zone = recordZone.zoneID

        // Load saved change token
        if let tokenData = UserDefaults.standard.data(forKey: changeTokenKey),
           let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData) {
            serverChangeToken = token
        }

        // Fetch zone changes
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = serverChangeToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zone],
            configurationsByRecordZoneID: [zone: configuration]
        )

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        operation.recordWasChangedBlock = { _, result in
            switch result {
            case .success(let record):
                changedRecords.append(record)
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneFetchResultBlock = { _, result in
            switch result {
            case .success(let (serverChangeToken, _, _)):
                self.serverChangeToken = serverChangeToken
                // Save change token
                if let tokenData = try? NSKeyedArchiver.archivedData(withRootObject: serverChangeToken, requiringSecureCoding: true) {
                    UserDefaults.standard.set(tokenData, forKey: self.changeTokenKey)
                }
            case .failure(let error):
                print("Error fetching zone changes: \(error)")
            }
        }

        try await privateDatabase.add(operation)

        // Process changes
        for record in changedRecords {
            try await processRemoteRecord(record)
        }

        // Process deletions
        for recordID in deletedRecordIDs {
            if let uuid = UUID(uuidString: recordID.recordName) {
                _ = database.deleteClipboardItem(uuid)
            }
        }

        await MainActor.run {
            stats.itemsDownloaded += changedRecords.count
        }
    }

    /// Upload local changes to iCloud
    private func uploadChanges() async throws {
        // For now, upload all items
        // TODO: Implement change tracking to only upload modified items
        let items = database.fetchAllClipboardItems()

        for item in items {
            let record = try createRecord(from: item)
            try await privateDatabase.save(record)
        }

        await MainActor.run {
            stats.itemsUploaded += items.count
        }
    }

    /// Process a remote record
    private func processRemoteRecord(_ record: CKRecord) async throws {
        let remoteItem = try createItem(from: record)

        // Check for local item
        if let localItem = database.fetchAllClipboardItems().first(where: { $0.id == remoteItem.id }) {
            // Conflict detected - compare timestamps
            if localItem.timestamp != remoteItem.timestamp {
                let conflict = SyncConflict(
                    localItem: localItem,
                    remoteItem: remoteItem,
                    recordID: record.recordID
                )

                await MainActor.run {
                    conflicts.append(conflict)
                }

                // Auto-resolve based on strategy
                if conflictResolution != .askUser {
                    try await resolveConflict(conflict, resolution: conflictResolution)
                }
            }
        } else {
            // New item from remote
            _ = database.saveClipboardItem(remoteItem)
        }
    }

    /// Create CloudKit record from clipboard item
    private func createRecord(from item: ClipboardItem) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: "ClipboardItem", recordID: recordID)

        // Store item data
        record["contentType"] = item.type.rawValue
        record["timestamp"] = item.timestamp
        record["sourceApp"] = item.sourceApp
        record["windowTitle"] = item.windowTitle
        record["workspaceId"] = item.workspaceId?.uuidString

        // Convert content to data
        let contentData: Data
        switch item.content {
        case .text(let text):
            contentData = Data(text.utf8)
        case .image(let imageData):
            contentData = imageData
        case .file(let url):
            contentData = Data(url.absoluteString.utf8)
        case .url(let url):
            contentData = Data(url.absoluteString.utf8)
        }

        // Encrypt sensitive content
        if item.isMarkedSensitive {
            if let encryptedContent = securityService.encrypt(contentData) {
                record["content"] = encryptedContent
                record["isEncrypted"] = true
            } else {
                record["content"] = contentData
                record["isEncrypted"] = false
            }
        } else {
            record["content"] = contentData
            record["isEncrypted"] = false
        }

        return record
    }

    /// Create clipboard item from CloudKit record
    private func createItem(from record: CKRecord) throws -> ClipboardItem {
        guard let contentType = record["contentType"] as? String,
              let type = ClipboardItemType(rawValue: contentType),
              let timestamp = record["timestamp"] as? Date,
              let sourceApp = record["sourceApp"] as? String else {
            throw SyncError.invalidRecord
        }

        var contentData: Data
        let isEncrypted = record["isEncrypted"] as? Bool ?? false

        if isEncrypted, let encryptedData = record["content"] as? Data {
            guard let decryptedData = securityService.decrypt(encryptedData) else {
                throw SyncError.invalidRecord
            }
            contentData = decryptedData
        } else if let data = record["content"] as? Data {
            contentData = data
        } else {
            throw SyncError.invalidRecord
        }

        let windowTitle = record["windowTitle"] as? String
        let workspaceIdString = record["workspaceId"] as? String
        let workspaceId = workspaceIdString.flatMap { UUID(uuidString: $0) }

        // Reconstruct content from data
        let content: ClipboardContent
        switch type {
        case .text, .code:
            content = .text(String(data: contentData, encoding: .utf8) ?? "")
        case .image:
            content = .image(contentData)
        case .file:
            // File URLs are stored as strings
            if let urlString = String(data: contentData, encoding: .utf8),
               let url = URL(string: urlString) {
                content = .file(url)
            } else {
                throw SyncError.invalidRecord
            }
        case .url:
            // URL type - extract URL
            if let urlString = String(data: contentData, encoding: .utf8),
               let url = URL(string: urlString) {
                content = .url(url)
            } else {
                throw SyncError.invalidRecord
            }
        }

        return ClipboardItem(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            content: content,
            type: type,
            timestamp: timestamp,
            sourceApp: sourceApp,
            windowTitle: windowTitle,
            workspaceId: workspaceId,
            isMarkedSensitive: isEncrypted
        )
    }

    /// Create custom CloudKit zone
    private func createCustomZone() async throws {
        do {
            try await privateDatabase.save(recordZone)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists
        }
    }

    /// Setup subscription for push notifications
    private func setupSubscription() async throws {
        let subscription = CKQuerySubscription(
            recordType: "ClipboardItem",
            predicate: NSPredicate(value: true),
            subscriptionID: "clipboard-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await privateDatabase.save(subscription)
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists
        }
    }

    // MARK: - State Persistence

    private func loadSyncState() {
        isEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        if let statsData = UserDefaults.standard.data(forKey: "syncStats"),
           let savedStats = try? JSONDecoder().decode(SyncStats.self, from: statsData) {
            stats = savedStats
        }
    }

    private func saveSyncState() {
        UserDefaults.standard.set(isEnabled, forKey: "iCloudSyncEnabled")

        if let statsData = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(statsData, forKey: "syncStats")
        }
    }

    private func setupSync() {
        Task {
            try? await createCustomZone()
            try? await setupSubscription()
        }
    }
}

// MARK: - Sync Errors

enum SyncError: LocalizedError {
    case iCloudUnavailable
    case syncDisabled
    case invalidRecord
    case conflictResolution
    case networkError

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud is not available. Please sign in to iCloud in System Preferences."
        case .syncDisabled:
            return "iCloud sync is disabled. Enable it in settings."
        case .invalidRecord:
            return "Invalid CloudKit record format."
        case .conflictResolution:
            return "Failed to resolve sync conflict."
        case .networkError:
            return "Network error during sync."
        }
    }
}

// MARK: - Codable Support

extension SyncStats: Codable {}
