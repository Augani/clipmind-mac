//
//  DatabaseService.swift
//  clipmind
//
//  SQLite database service for clipboard history persistence
//

import Foundation
import SQLite3

/// Database service managing SQLite persistence for clipboard items
class DatabaseService {
    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private let dbPath: String
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init() {
        // Database file in Application Support directory
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let clipmindDir = appSupport.appendingPathComponent("ClipMind", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: clipmindDir, withIntermediateDirectories: true)

        dbPath = clipmindDir.appendingPathComponent("clipboard.db").path
        openDatabase()
        createTables()
    }

    // MARK: - Database Connection

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            return
        }

        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size = -8000;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA mmap_size = 33554432;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA temp_store = MEMORY;", nil, nil, nil)
    }

    private func createTables() {
        // Clipboard items table
        let createClipboardItemsTable = """
        CREATE TABLE IF NOT EXISTS clipboard_items (
            id TEXT PRIMARY KEY,
            content_type TEXT NOT NULL,
            content_value BLOB NOT NULL,
            item_type TEXT NOT NULL,
            timestamp REAL NOT NULL,
            source_app TEXT NOT NULL,
            source_bundle_id TEXT,
            window_title TEXT,
            workspace_id TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """

        // Metadata table
        let createMetadataTable = """
        CREATE TABLE IF NOT EXISTS metadata (
            id TEXT PRIMARY KEY,
            clipboard_item_id TEXT NOT NULL,
            tags TEXT,
            usage_count INTEGER DEFAULT 0,
            is_archived INTEGER DEFAULT 0,
            is_sensitive INTEGER DEFAULT 0,
            last_used_at REAL,
            FOREIGN KEY (clipboard_item_id) REFERENCES clipboard_items(id) ON DELETE CASCADE
        );
        """

        // Workspaces table
        let createWorkspacesTable = """
        CREATE TABLE IF NOT EXISTS workspaces (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT,
            app_filter TEXT,
            project_path TEXT,
            auto_tag_rules TEXT,
            created_at REAL NOT NULL
        );
        """

        let createIndexes = """
        CREATE INDEX IF NOT EXISTS idx_timestamp ON clipboard_items(timestamp DESC);
        CREATE INDEX IF NOT EXISTS idx_item_type ON clipboard_items(item_type);
        CREATE INDEX IF NOT EXISTS idx_workspace_id ON clipboard_items(workspace_id);
        CREATE INDEX IF NOT EXISTS idx_source_app ON clipboard_items(source_app);
        CREATE INDEX IF NOT EXISTS idx_metadata_item_id ON metadata(clipboard_item_id);
        """

        executeSQL(createClipboardItemsTable)
        executeSQL(createMetadataTable)
        executeSQL(createWorkspacesTable)
        executeSQL(createIndexes)

        addActivityContextColumnsIfNeeded()
    }

    private func addActivityContextColumnsIfNeeded() {
        cleanupCorruptedRows()

        let columns = [
            ("time_category", "TEXT"),
            ("day_category", "TEXT"),
            ("git_branch", "TEXT"),
            ("project_path", "TEXT"),
            ("browser_url", "TEXT"),
            ("browser_title", "TEXT"),
            ("activity_session_id", "TEXT"),
            ("origin", "TEXT")
        ]

        for (columnName, columnType) in columns {
            let checkSQL = "SELECT COUNT(*) as count FROM pragma_table_info('clipboard_items') WHERE name='\(columnName)';"

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, checkSQL, -1, &statement, nil) == SQLITE_OK else {
                continue
            }

            var columnExists = false
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                columnExists = count > 0
            }
            sqlite3_finalize(statement)

            if !columnExists {
                let addColumnSQL = "ALTER TABLE clipboard_items ADD COLUMN \(columnName) \(columnType);"
                executeSQL(addColumnSQL)
            }
        }

        let indexSQL = """
        CREATE INDEX IF NOT EXISTS idx_time_category ON clipboard_items(time_category);
        CREATE INDEX IF NOT EXISTS idx_day_category ON clipboard_items(day_category);
        CREATE INDEX IF NOT EXISTS idx_git_branch ON clipboard_items(git_branch);
        CREATE INDEX IF NOT EXISTS idx_browser_url ON clipboard_items(browser_url);
        CREATE INDEX IF NOT EXISTS idx_activity_session ON clipboard_items(activity_session_id);
        """
        executeSQL(indexSQL)

        backfillActivityContext()
    }

    private func backfillActivityContext() {
        let checkSQL = "SELECT COUNT(*) FROM clipboard_items WHERE time_category IS NULL;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, checkSQL, -1, &statement, nil) == SQLITE_OK else {
            return
        }

        var needsBackfill = false
        if sqlite3_step(statement) == SQLITE_ROW {
            let count = sqlite3_column_int(statement, 0)
            needsBackfill = count > 0
        }
        sqlite3_finalize(statement)

        guard needsBackfill else { return }

        let selectSQL = "SELECT id, timestamp FROM clipboard_items WHERE time_category IS NULL;"
        guard sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK else {
            return
        }

        var updates: [(String, TimeCategory, DayCategory)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let idString = String(cString: sqlite3_column_text(statement, 0))
            let timestamp = sqlite3_column_double(statement, 1)
            let date = Date(timeIntervalSince1970: timestamp)
            let timeCategory = TimeCategory.from(date: date)
            let dayCategory = DayCategory.from(date: date)
            updates.append((idString, timeCategory, dayCategory))
        }
        sqlite3_finalize(statement)

        let updateSQL = "UPDATE clipboard_items SET time_category = ?, day_category = ? WHERE id = ?;"
        for (itemId, timeCategory, dayCategory) in updates {
            var updateStatement: OpaquePointer?
            guard sqlite3_prepare_v2(db, updateSQL, -1, &updateStatement, nil) == SQLITE_OK else {
                continue
            }
            sqlite3_bind_text(updateStatement, 1, (timeCategory.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(updateStatement, 2, (dayCategory.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(updateStatement, 3, (itemId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(updateStatement)
            sqlite3_finalize(updateStatement)
        }
    }

    private func executeSQL(_ sql: String) {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let errorMessage = String(cString: error!)
            print("Error executing SQL: \(errorMessage)")
            sqlite3_free(error)
        }
    }

    private func cleanupCorruptedRows() {
        let sql = "SELECT id FROM clipboard_items WHERE id NOT GLOB '[0-9a-fA-F]*-[0-9a-fA-F]*-[0-9a-fA-F]*-[0-9a-fA-F]*-[0-9a-fA-F]*';"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        var corruptedIds: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            corruptedIds.append(String(cString: sqlite3_column_text(statement, 0)))
        }

        guard !corruptedIds.isEmpty else { return }

        for corruptedId in corruptedIds {
            let deleteSql = "DELETE FROM clipboard_items WHERE id = ?;"
            var deleteStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSql, -1, &deleteStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(deleteStmt, 1, (corruptedId as NSString).utf8String, -1, nil)
                sqlite3_step(deleteStmt)
            }
            sqlite3_finalize(deleteStmt)
        }
    }

    // MARK: - Clipboard Items CRUD

    func saveClipboardItem(_ item: ClipboardItem) -> Bool {
        let sql = """
        INSERT OR REPLACE INTO clipboard_items
        (id, content_type, content_value, item_type, timestamp, source_app, source_bundle_id, window_title, workspace_id, created_at, updated_at, time_category, day_category, git_branch, project_path, browser_url, browser_title, activity_session_id, origin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing insert statement")
            return false
        }

        defer { sqlite3_finalize(statement) }

        guard let (contentType, contentData) = serializeContent(item.content) else {
            print("❌ Failed to serialize content")
            return false
        }

        let now = Date().timeIntervalSince1970

        sqlite3_bind_text(statement, 1, (item.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (contentType as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_blob(statement, 3, (contentData as NSData).bytes, Int32(contentData.count), SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, (item.type.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 5, item.timestamp.timeIntervalSince1970)
        sqlite3_bind_text(statement, 6, (item.sourceApp as NSString).utf8String, -1, SQLITE_TRANSIENT)

        if let sourceBundleId = item.sourceBundleIdentifier {
            sqlite3_bind_text(statement, 7, (sourceBundleId as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if let windowTitle = item.windowTitle {
            sqlite3_bind_text(statement, 8, (windowTitle as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 8)
        }

        if let workspaceId = item.workspaceId {
            sqlite3_bind_text(statement, 9, (workspaceId.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 9)
        }

        sqlite3_bind_double(statement, 10, now)
        sqlite3_bind_double(statement, 11, now)

        let context = item.activityContext
        let timeCategory = context?.timeCategory ?? TimeCategory.from(date: item.timestamp)
        let dayCategory = context?.dayCategory ?? DayCategory.from(date: item.timestamp)

        sqlite3_bind_text(statement, 12, (timeCategory.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 13, (dayCategory.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)

        if let gitBranch = context?.gitBranch {
            sqlite3_bind_text(statement, 14, (gitBranch as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 14)
        }

        if let projectPath = context?.projectPath {
            sqlite3_bind_text(statement, 15, (projectPath as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 15)
        }

        if let browserUrl = context?.browserTabUrl {
            sqlite3_bind_text(statement, 16, (browserUrl as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 16)
        }

        if let browserTitle = context?.browserTabTitle {
            sqlite3_bind_text(statement, 17, (browserTitle as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 17)
        }

        if let sessionId = context?.activitySessionId {
            sqlite3_bind_text(statement, 18, (sessionId.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 18)
        }

        sqlite3_bind_text(statement, 19, (item.origin.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)

        return sqlite3_step(statement) == SQLITE_DONE
    }

    func fetchAllClipboardItems(limit: Int = 1000) -> [ClipboardItem] {
        return fetchClipboardItems(limit: limit, offset: 0)
    }

    /// Fetch clipboard items with pagination support for lazy loading
    func fetchClipboardItems(limit: Int = 100, offset: Int = 0, workspaceId: UUID? = nil) -> [ClipboardItem] {
        var sql = """
        SELECT id, content_type, content_value, item_type, timestamp, source_app,
               source_bundle_id, window_title, workspace_id,
               time_category, day_category, git_branch, project_path, browser_url, browser_title, activity_session_id, origin
        FROM clipboard_items
        """

        if workspaceId != nil {
            sql += " WHERE workspace_id = ?"
        }

        sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?;"

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing select statement: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }

        defer { sqlite3_finalize(statement) }

        var bindIndex: Int32 = 1

        if let workspaceId = workspaceId {
            sqlite3_bind_text(statement, bindIndex, (workspaceId.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            bindIndex += 1
        }

        sqlite3_bind_int(statement, bindIndex, Int32(limit))
        sqlite3_bind_int(statement, bindIndex + 1, Int32(offset))

        var items: [ClipboardItem] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseClipboardItem(from: statement) {
                items.append(item)
            }
        }

        return items
    }

    /// Get total count of clipboard items
    func getClipboardItemCount(workspaceId: UUID? = nil) -> Int {
        var sql = "SELECT COUNT(*) FROM clipboard_items"

        if workspaceId != nil {
            sql += " WHERE workspace_id = ?"
        }

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }

        defer { sqlite3_finalize(statement) }

        if let workspaceId = workspaceId {
            sqlite3_bind_text(statement, 1, (workspaceId.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    func fetchClipboardItemPreviews(limit: Int = 50, offset: Int = 0, workspaceId: UUID? = nil) -> [ClipboardItem] {
        var sql = """
        SELECT id,
            content_type,
            CASE
                WHEN content_type = 'text' THEN SUBSTR(content_value, 1, 600)
                WHEN content_type = 'image' THEN X''
                ELSE content_value
            END as content_value,
            item_type, timestamp, source_app,
            source_bundle_id, window_title, workspace_id,
            time_category, day_category, git_branch, project_path, browser_url, browser_title, activity_session_id, origin
        FROM clipboard_items
        """

        if workspaceId != nil {
            sql += " WHERE workspace_id = ?"
        }

        sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?;"

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        var bindIndex: Int32 = 1

        if let workspaceId = workspaceId {
            sqlite3_bind_text(statement, bindIndex, (workspaceId.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            bindIndex += 1
        }

        sqlite3_bind_int(statement, bindIndex, Int32(limit))
        sqlite3_bind_int(statement, bindIndex + 1, Int32(offset))

        var items: [ClipboardItem] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseClipboardItem(from: statement) {
                items.append(item)
            }
        }

        return items
    }

    func fetchFullClipboardItem(id: UUID) -> ClipboardItem? {
        let sql = """
        SELECT id, content_type, content_value, item_type, timestamp, source_app,
               source_bundle_id, window_title, workspace_id,
               time_category, day_category, git_branch, project_path, browser_url, browser_title, activity_session_id, origin
        FROM clipboard_items
        WHERE id = ?;
        """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return parseClipboardItem(from: statement)
    }

    func searchClipboardItems(
        query: String?,
        types: Set<ClipboardItemType> = [],
        workspaceIds: Set<UUID> = [],
        dateStart: Date? = nil,
        dateEnd: Date? = nil,
        sensitiveOnly: Bool = false,
        limit: Int = 500
    ) -> [ClipboardItem] {
        var conditions: [String] = []
        var bindings: [(Int32, Any)] = []
        var bindIndex: Int32 = 1

        if let query = query, !query.isEmpty {
            conditions.append("(content_type != 'image' AND CAST(content_value AS TEXT) LIKE ?)")
            bindings.append((bindIndex, "%\(query)%"))
            bindIndex += 1
        }

        if !types.isEmpty {
            let placeholders = types.map { _ in "?" }.joined(separator: ", ")
            conditions.append("item_type IN (\(placeholders))")
            for itemType in types {
                bindings.append((bindIndex, itemType.rawValue))
                bindIndex += 1
            }
        }

        if !workspaceIds.isEmpty {
            let placeholders = workspaceIds.map { _ in "?" }.joined(separator: ", ")
            conditions.append("workspace_id IN (\(placeholders))")
            for wsId in workspaceIds {
                bindings.append((bindIndex, wsId.uuidString))
                bindIndex += 1
            }
        }

        if let start = dateStart {
            conditions.append("timestamp >= ?")
            bindings.append((bindIndex, start.timeIntervalSince1970))
            bindIndex += 1
        }

        if let end = dateEnd {
            conditions.append("timestamp <= ?")
            bindings.append((bindIndex, end.timeIntervalSince1970))
            bindIndex += 1
        }

        if sensitiveOnly {
            conditions.append("""
                id IN (SELECT clipboard_item_id FROM metadata WHERE is_sensitive = 1)
            """)
        }

        var sql = """
        SELECT id,
            content_type,
            CASE
                WHEN content_type = 'text' THEN SUBSTR(content_value, 1, 600)
                WHEN content_type = 'image' THEN X''
                ELSE content_value
            END as content_value,
            item_type, timestamp, source_app,
            source_bundle_id, window_title, workspace_id,
            time_category, day_category, git_branch, project_path, browser_url, browser_title, activity_session_id, origin
        FROM clipboard_items
        """

        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }

        sql += " ORDER BY timestamp DESC LIMIT ?;"
        bindings.append((bindIndex, limit))

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        for (idx, value) in bindings {
            switch value {
            case let s as String:
                sqlite3_bind_text(statement, idx, (s as NSString).utf8String, -1, SQLITE_TRANSIENT)
            case let d as Double:
                sqlite3_bind_double(statement, idx, d)
            case let i as Int:
                sqlite3_bind_int(statement, idx, Int32(i))
            default:
                break
            }
        }

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseClipboardItem(from: statement) {
                items.append(item)
            }
        }
        return items
    }

    func deleteClipboardItem(_ id: UUID) -> Bool {
        let sql = "DELETE FROM clipboard_items WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)

        return sqlite3_step(statement) == SQLITE_DONE
    }

    func deleteClipboardItems(olderThan timestamp: TimeInterval) -> Int {
        let sql = "DELETE FROM clipboard_items WHERE timestamp < ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, timestamp)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            return 0
        }

        return Int(sqlite3_changes(db))
    }

    func clearAllClipboardItems() -> Bool {
        return executeSQL("DELETE FROM clipboard_items;") == Void()
    }

    /// Update workspace_id for a clipboard item
    func updateClipboardItemWorkspace(_ itemId: UUID, workspaceId: UUID?) -> Bool {
        let sql = "UPDATE clipboard_items SET workspace_id = ?, updated_at = ? WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        defer { sqlite3_finalize(statement) }

        if let workspaceId = workspaceId {
            sqlite3_bind_text(statement, 1, (workspaceId.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 1)
        }

        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, (itemId.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)

        return sqlite3_step(statement) == SQLITE_DONE
    }

    // MARK: - Workspaces CRUD

    /// Save a workspace to the database
    func saveWorkspace(_ workspace: Workspace) -> Bool {
        let sql = """
        INSERT OR REPLACE INTO workspaces
        (id, name, color, app_filter, project_path, auto_tag_rules, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing workspace insert statement")
            return false
        }

        defer { sqlite3_finalize(statement) }

        // Serialize app_filter array to JSON
        let appFilterJSON = (try? JSONEncoder().encode(workspace.appFilter))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        sqlite3_bind_text(statement, 1, (workspace.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (workspace.name as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, (workspace.color as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, (appFilterJSON as NSString).utf8String, -1, SQLITE_TRANSIENT)

        if let projectPath = workspace.projectPath {
            sqlite3_bind_text(statement, 5, (projectPath as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let autoTagRules = workspace.autoTagRules {
            sqlite3_bind_text(statement, 6, (autoTagRules as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 6)
        }

        sqlite3_bind_double(statement, 7, workspace.createdAt.timeIntervalSince1970)

        return sqlite3_step(statement) == SQLITE_DONE
    }

    /// Fetch all workspaces from the database
    func fetchAllWorkspaces() -> [Workspace] {
        let sql = "SELECT * FROM workspaces ORDER BY created_at ASC;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing workspace select statement")
            return []
        }

        defer { sqlite3_finalize(statement) }

        var workspaces: [Workspace] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            if let workspace = parseWorkspace(from: statement) {
                workspaces.append(workspace)
            }
        }

        return workspaces
    }

    /// Delete a workspace from the database
    func deleteWorkspace(_ id: UUID) -> Bool {
        // First, set workspace_id to null for all items in this workspace
        let updateItemsSQL = "UPDATE clipboard_items SET workspace_id = NULL WHERE workspace_id = ?;"
        var updateStatement: OpaquePointer?

        if sqlite3_prepare_v2(db, updateItemsSQL, -1, &updateStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(updateStatement, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(updateStatement)
            sqlite3_finalize(updateStatement)
        }

        // Delete the workspace
        let sql = "DELETE FROM workspaces WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)

        return sqlite3_step(statement) == SQLITE_DONE
    }

    // MARK: - Helper Methods

    private func serializeContent(_ content: ClipboardContent) -> (String, Data)? {
        switch content {
        case .text(let string):
            guard let data = string.data(using: .utf8) else { return nil }
            return ("text", data)

        case .image(let imageData):
            return ("image", imageData)

        case .file(let url):
            guard let data = url.absoluteString.data(using: .utf8) else { return nil }
            return ("file", data)

        case .url(let url):
            guard let data = url.absoluteString.data(using: .utf8) else { return nil }
            return ("url", data)
        }
    }

    private func deserializeContent(type: String, data: Data) -> ClipboardContent? {
        switch type {
        case "text":
            guard let string = String(data: data, encoding: .utf8) else { return nil }
            return .text(string)

        case "image":
            return .image(data)

        case "file":
            guard let string = String(data: data, encoding: .utf8),
                  let url = URL(string: string) else { return nil }
            return .file(url)

        case "url":
            guard let string = String(data: data, encoding: .utf8),
                  let url = URL(string: string) else { return nil }
            return .url(url)

        default:
            return nil
        }
    }

    private func parseClipboardItem(from statement: OpaquePointer?) -> ClipboardItem? {
        guard let statement = statement,
              sqlite3_column_text(statement, 0) != nil,
              sqlite3_column_text(statement, 1) != nil,
              sqlite3_column_text(statement, 3) != nil,
              sqlite3_column_text(statement, 5) != nil else {
            return nil
        }

        let idString = String(cString: sqlite3_column_text(statement, 0))
        let contentType = String(cString: sqlite3_column_text(statement, 1))
        let contentBlob = sqlite3_column_blob(statement, 2)
        let contentLength = sqlite3_column_bytes(statement, 2)
        let itemTypeString = String(cString: sqlite3_column_text(statement, 3))
        let timestamp = sqlite3_column_double(statement, 4)
        let sourceApp = String(cString: sqlite3_column_text(statement, 5))
        let sourceBundleId = sqlite3_column_text(statement, 6).map { String(cString: $0) }
        let windowTitle = sqlite3_column_text(statement, 7).map { String(cString: $0) }
        let workspaceIdString = sqlite3_column_text(statement, 8).map { String(cString: $0) }

        let timeCategoryStr = sqlite3_column_text(statement, 9).map { String(cString: $0) }
        let dayCategoryStr = sqlite3_column_text(statement, 10).map { String(cString: $0) }
        let gitBranch = sqlite3_column_text(statement, 11).map { String(cString: $0) }
        let projectPath = sqlite3_column_text(statement, 12).map { String(cString: $0) }
        let browserUrl = sqlite3_column_text(statement, 13).map { String(cString: $0) }
        let browserTitle = sqlite3_column_text(statement, 14).map { String(cString: $0) }
        let sessionIdStr = sqlite3_column_text(statement, 15).map { String(cString: $0) }
        let originStr = sqlite3_column_text(statement, 16).map { String(cString: $0) }

        guard let id = UUID(uuidString: idString),
              let contentData = contentBlob.map({ Data(bytes: $0, count: Int(contentLength)) }),
              let content = deserializeContent(type: contentType, data: contentData),
              let itemType = ClipboardItemType(rawValue: itemTypeString) else {
            return nil
        }

        let itemDate = Date(timeIntervalSince1970: timestamp)

        var activityContext: ActivityContext? = nil
        if timeCategoryStr != nil || dayCategoryStr != nil || gitBranch != nil ||
           projectPath != nil || browserUrl != nil || browserTitle != nil || sessionIdStr != nil {
            activityContext = ActivityContext(
                timeCategory: timeCategoryStr.flatMap { TimeCategory(rawValue: $0) } ?? TimeCategory.from(date: itemDate),
                dayCategory: dayCategoryStr.flatMap { DayCategory(rawValue: $0) } ?? DayCategory.from(date: itemDate),
                gitBranch: gitBranch,
                projectPath: projectPath,
                browserTabUrl: browserUrl,
                browserTabTitle: browserTitle,
                activitySessionId: sessionIdStr.flatMap { UUID(uuidString: $0) }
            )
        }

        return ClipboardItem(
            id: id,
            content: content,
            type: itemType,
            timestamp: itemDate,
            sourceApp: sourceApp,
            sourceBundleIdentifier: sourceBundleId,
            windowTitle: windowTitle,
            workspaceId: workspaceIdString.flatMap { UUID(uuidString: $0) },
            activityContext: activityContext,
            origin: originStr.flatMap { ClipboardOrigin(rawValue: $0) } ?? .local
        )
    }

    private func parseWorkspace(from statement: OpaquePointer?) -> Workspace? {
        guard let statement = statement else { return nil }

        // Parse columns
        let idString = String(cString: sqlite3_column_text(statement, 0))
        let name = String(cString: sqlite3_column_text(statement, 1))
        let color = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : "#8E8E93"
        let appFilterJSON = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)) : "[]"
        let projectPath = sqlite3_column_text(statement, 4) != nil ? String(cString: sqlite3_column_text(statement, 4)) : nil
        let autoTagRules = sqlite3_column_text(statement, 5) != nil ? String(cString: sqlite3_column_text(statement, 5)) : nil
        let createdAt = sqlite3_column_double(statement, 6)

        guard let id = UUID(uuidString: idString) else {
            return nil
        }

        // Deserialize app_filter JSON
        let appFilter: [String] = (try? JSONDecoder().decode([String].self, from: Data(appFilterJSON.utf8))) ?? []

        return Workspace(
            id: id,
            name: name,
            color: color,
            appFilter: appFilter,
            projectPath: projectPath,
            autoTagRules: autoTagRules,
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }

    // MARK: - Activity Context Search

    func fetchItemsByTimeCategory(_ category: TimeCategory, limit: Int = 100) -> [ClipboardItem] {
        let sql = """
        SELECT id, content_type, content_value, item_type, timestamp, source_app,
               source_bundle_id, window_title, workspace_id,
               time_category, day_category, git_branch, project_path, browser_url, browser_title, activity_session_id, origin
        FROM clipboard_items
        WHERE time_category = ?
        ORDER BY timestamp DESC LIMIT ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (category.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseClipboardItem(from: statement) {
                items.append(item)
            }
        }
        return items
    }

    func fetchItemsBySourceApp(_ app: String, limit: Int = 100) -> [ClipboardItem] {
        let sql = """
        SELECT id, content_type, content_value, item_type, timestamp, source_app,
               source_bundle_id, window_title, workspace_id,
               time_category, day_category, git_branch, project_path, browser_url, browser_title, activity_session_id, origin
        FROM clipboard_items
        WHERE LOWER(source_app) LIKE ?
        ORDER BY timestamp DESC LIMIT ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, ("%\(app.lowercased())%" as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseClipboardItem(from: statement) {
                items.append(item)
            }
        }
        return items
    }

    func fetchItemsByGitBranch(_ branch: String, limit: Int = 100) -> [ClipboardItem] {
        let sql = """
        SELECT id, content_type, content_value, item_type, timestamp, source_app,
               source_bundle_id, window_title, workspace_id,
               time_category, day_category, git_branch, project_path, browser_url, browser_title, activity_session_id, origin
        FROM clipboard_items
        WHERE LOWER(git_branch) LIKE ?
        ORDER BY timestamp DESC LIMIT ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, ("%\(branch.lowercased())%" as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseClipboardItem(from: statement) {
                items.append(item)
            }
        }
        return items
    }

    func fetchItemsByBrowserDomain(_ domain: String, limit: Int = 100) -> [ClipboardItem] {
        let sql = """
        SELECT id, content_type, content_value, item_type, timestamp, source_app,
               source_bundle_id, window_title, workspace_id,
               time_category, day_category, git_branch, project_path, browser_url, browser_title, activity_session_id, origin
        FROM clipboard_items
        WHERE LOWER(browser_url) LIKE ?
        ORDER BY timestamp DESC LIMIT ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, ("%\(domain.lowercased())%" as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseClipboardItem(from: statement) {
                items.append(item)
            }
        }
        return items
    }

    func getDistinctSourceApps(limit: Int = 20) -> [String] {
        let sql = """
        SELECT source_app, COUNT(*) as cnt
        FROM clipboard_items
        GROUP BY source_app
        ORDER BY cnt DESC
        LIMIT ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var apps: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let appName = sqlite3_column_text(statement, 0) {
                apps.append(String(cString: appName))
            }
        }
        return apps
    }

    // MARK: - Performance & Statistics

    /// Get database performance statistics
    func getDatabaseStats() -> DatabaseStats {
        var stats = DatabaseStats()

        // Get database file size
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: dbPath)[.size] as? Int64 {
            stats.fileSizeBytes = fileSize
            stats.fileSizeMB = Double(fileSize) / 1_048_576.0  // Convert to MB
        }

        // Get total item count
        let countSQL = "SELECT COUNT(*) FROM clipboard_items;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                stats.totalItems = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        // Get page size and page count
        let pageSizeSQL = "PRAGMA page_size;"
        if sqlite3_prepare_v2(db, pageSizeSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                stats.pageSize = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        let pageCountSQL = "PRAGMA page_count;"
        if sqlite3_prepare_v2(db, pageCountSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                stats.pageCount = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        // Get workspace count
        let workspaceCountSQL = "SELECT COUNT(*) FROM workspaces;"
        if sqlite3_prepare_v2(db, workspaceCountSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                stats.workspaceCount = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        return stats
    }

    /// Vacuum database to reclaim space
    func vacuumDatabase() {
        sqlite3_exec(db, "VACUUM;", nil, nil, nil)
    }

    /// Optimize database for better performance
    func optimizeDatabase() {
        // Analyze tables to update query planner statistics
        sqlite3_exec(db, "ANALYZE;", nil, nil, nil)

        // Optimize database file
        sqlite3_exec(db, "PRAGMA optimize;", nil, nil, nil)
    }

    /// Get memory-mapped I/O setting
    func getMemoryMapSize() -> Int64 {
        var statement: OpaquePointer?
        var size: Int64 = 0

        let sql = "PRAGMA mmap_size;"
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                size = sqlite3_column_int64(statement, 0)
            }
        }
        sqlite3_finalize(statement)

        return size
    }

    /// Set memory-mapped I/O size for better performance (default: 32MB)
    func setMemoryMapSize(_ size: Int64 = 33_554_432) {
        let sql = "PRAGMA mmap_size = \(size);"
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
}

// MARK: - Database Statistics

struct DatabaseStats {
    var fileSizeBytes: Int64 = 0
    var fileSizeMB: Double = 0
    var totalItems: Int = 0
    var pageSize: Int = 0
    var pageCount: Int = 0
    var workspaceCount: Int = 0
}
