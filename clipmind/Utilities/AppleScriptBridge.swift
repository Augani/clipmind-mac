//
//  AppleScriptBridge.swift
//  clipmind
//
//  AppleScript and automation support for ClipMind
//

import Foundation
import AppKit

// MARK: - Scriptable Application

/// Make ClipMind scriptable via AppleScript
class ScriptableClipMind: NSObject {
    static let shared = ScriptableClipMind()

    // Reference to the clipboard store
    internal var clipboardStore: ClipboardStore?

    func setClipboardStore(_ store: ClipboardStore) {
        self.clipboardStore = store
    }

    // MARK: - Scriptable Properties

    /// Get all clipboard items
    @objc var clipboardItems: [ScriptableClipboardItem] {
        guard let store = clipboardStore else { return [] }
        return store.items.map { ScriptableClipboardItem(item: $0) }
    }

    /// Get clipboard item count
    @objc var itemCount: Int {
        clipboardStore?.items.count ?? 0
    }

    /// Get all workspaces
    @objc var workspaces: [ScriptableWorkspace] {
        guard let store = clipboardStore else { return [] }
        return store.workspaceService.workspaces.map { ScriptableWorkspace(workspace: $0) }
    }

    // MARK: - Scriptable Commands

    /// Search clipboard items
    @objc func search(_ query: String) -> [ScriptableClipboardItem] {
        guard let store = clipboardStore else { return [] }
        let results = store.search(query)
        return results.map { ScriptableClipboardItem(item: $0) }
    }

    /// Copy item to clipboard by ID
    @objc func copyItem(withId id: String) -> Bool {
        guard let store = clipboardStore,
              let uuid = UUID(uuidString: id),
              let item = store.items.first(where: { $0.id == uuid }) else {
            return false
        }

        store.copyItemToClipboard(item)
        return true
    }

    /// Delete item by ID
    @objc func deleteItem(withId id: String) -> Bool {
        guard let store = clipboardStore,
              let uuid = UUID(uuidString: id),
              let item = store.items.first(where: { $0.id == uuid }) else {
            return false
        }

        store.deleteItem(item)
        return true
    }

    /// Clear all clipboard items
    @objc func clearAllItems() {
        clipboardStore?.clearAll()
    }

    /// Get items from a specific workspace
    @objc func items(inWorkspace workspaceName: String) -> [ScriptableClipboardItem] {
        guard let store = clipboardStore else { return [] }

        // Find workspace by name
        guard let workspace = store.workspaceService.workspaces.first(where: { $0.name == workspaceName }) else {
            return []
        }

        let items = store.items(forWorkspace: workspace.id)
        return items.map { ScriptableClipboardItem(item: $0) }
    }
}

// MARK: - Scriptable Clipboard Item

/// Scriptable wrapper for ClipboardItem
@objc class ScriptableClipboardItem: NSObject {
    private let item: ClipboardItem

    init(item: ClipboardItem) {
        self.item = item
        super.init()
    }

    @objc var id: String {
        item.id.uuidString
    }

    @objc var content: String {
        item.previewText
    }

    @objc var type: String {
        item.type.rawValue
    }

    @objc var sourceApp: String {
        item.sourceApp
    }

    @objc var windowTitle: String {
        item.windowTitle ?? ""
    }

    @objc var timestamp: Date {
        item.timestamp
    }

    @objc var workspaceName: String {
        // Would need to lookup workspace name from ID
        ""
    }

    @objc var isSensitive: Bool {
        item.isMarkedSensitive
    }

    // Return dictionary representation for AppleScript
    @objc override var scriptingProperties: [String: Any]? {
        get {
            return [
                "id": id,
                "content": content,
                "type": type,
                "sourceApp": sourceApp,
                "windowTitle": windowTitle,
                "timestamp": timestamp,
                "isSensitive": isSensitive
            ]
        }
        set {
            // Read-only properties
        }
    }
}

// MARK: - Scriptable Workspace

/// Scriptable wrapper for Workspace
@objc class ScriptableWorkspace: NSObject {
    private let workspace: Workspace

    init(workspace: Workspace) {
        self.workspace = workspace
        super.init()
    }

    @objc var id: String {
        workspace.id.uuidString
    }

    @objc var name: String {
        workspace.name
    }

    @objc var color: String {
        workspace.color
    }

    @objc override var scriptingProperties: [String: Any]? {
        get {
            return [
                "id": id,
                "name": name,
                "color": color
            ]
        }
        set {
            // Read-only properties
        }
    }
}

// MARK: - Custom Script Commands

/// Base class for custom AppleScript commands
class ClipMindScriptCommand: NSScriptCommand {
    var clipboardStore: ClipboardStore? {
        // Access clipboard store through the scriptable singleton
        ScriptableClipMind.shared.clipboardStore
    }
}

/// Search command
class SearchCommand: ClipMindScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let query = directParameter as? String else {
            scriptErrorNumber = errOSACantAccess
            return nil
        }

        let results = ScriptableClipMind.shared.search(query)
        return results
    }
}

/// Copy item command
class CopyItemCommand: ClipMindScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let itemId = directParameter as? String else {
            scriptErrorNumber = errOSACantAccess
            return nil
        }

        let success = ScriptableClipMind.shared.copyItem(withId: itemId)
        return success
    }
}

/// Delete item command
class DeleteItemCommand: ClipMindScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let itemId = directParameter as? String else {
            scriptErrorNumber = errOSACantAccess
            return nil
        }

        let success = ScriptableClipMind.shared.deleteItem(withId: itemId)
        return success
    }
}

/// Clear all command
class ClearAllCommand: ClipMindScriptCommand {
    override func performDefaultImplementation() -> Any? {
        ScriptableClipMind.shared.clearAllItems()
        return true
    }
}
