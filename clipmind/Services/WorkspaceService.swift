//
//  WorkspaceService.swift
//  clipmind
//
//  Service for managing workspaces with database persistence
//

import Foundation
import Combine

/// Service managing workspace CRUD operations and auto-assignment logic
class WorkspaceService: ObservableObject {
    @Published private(set) var workspaces: [Workspace] = []

    private let database = DatabaseService.shared

    init() {
        loadWorkspaces()

        // Remove any duplicate workspaces
        removeDuplicates()

        // Create default workspace if none exist
        if workspaces.isEmpty {
            let defaultWorkspace = Workspace.uncategorized
            _ = saveWorkspace(defaultWorkspace)
            // Note: saveWorkspace already appends to the array, no need to append again
        }
    }

    // MARK: - CRUD Operations

    /// Save a workspace to the database
    @discardableResult
    func saveWorkspace(_ workspace: Workspace) -> Bool {
        let success = database.saveWorkspace(workspace)
        if success {
            // Update in-memory list
            if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
                workspaces[index] = workspace
            } else {
                workspaces.append(workspace)
            }
        }
        return success
    }

    /// Update an existing workspace
    @discardableResult
    func updateWorkspace(_ workspace: Workspace) -> Bool {
        return saveWorkspace(workspace)
    }

    /// Delete a workspace
    @discardableResult
    func deleteWorkspace(_ workspace: Workspace) -> Bool {
        // Don't allow deleting the uncategorized workspace
        guard workspace.id != Workspace.uncategorized.id else {
            return false
        }

        let success = database.deleteWorkspace(workspace.id)
        if success {
            workspaces.removeAll { $0.id == workspace.id }
        }
        return success
    }

    /// Get workspace by ID
    func workspace(withId id: UUID) -> Workspace? {
        return workspaces.first { $0.id == id }
    }

    // MARK: - Auto-Assignment

    /// Auto-assign a workspace to a clipboard item based on matching rules
    func autoAssignWorkspace(for item: ClipboardItem) -> UUID? {
        // Check each workspace for a match (skip uncategorized)
        for workspace in workspaces where workspace.id != Workspace.uncategorized.id {
            if workspace.matches(item) {
                return workspace.id
            }
        }

        // Default to uncategorized
        return Workspace.uncategorized.id
    }

    /// Assign a workspace to a clipboard item
    @discardableResult
    func assignWorkspace(_ workspaceId: UUID, to itemId: UUID) -> Bool {
        return database.updateClipboardItemWorkspace(itemId, workspaceId: workspaceId)
    }

    // MARK: - Loading

    /// Load all workspaces from database
    private func loadWorkspaces() {
        workspaces = database.fetchAllWorkspaces()
    }

    /// Reload workspaces from database
    func reloadWorkspaces() {
        loadWorkspaces()
    }

    /// Remove duplicate workspaces from the in-memory array
    private func removeDuplicates() {
        var seenIds = Set<UUID>()
        var uniqueWorkspaces: [Workspace] = []

        for workspace in workspaces {
            if !seenIds.contains(workspace.id) {
                seenIds.insert(workspace.id)
                uniqueWorkspaces.append(workspace)
            }
        }

        workspaces = uniqueWorkspaces
    }
}

// MARK: - Predefined Color Palette

extension WorkspaceService {
    /// Predefined color palette for workspaces
    static let colorPalette: [String] = [
        "#007AFF",  // Blue
        "#FF2D55",  // Pink
        "#34C759",  // Green
        "#FF9500",  // Orange
        "#AF52DE",  // Purple
        "#FF3B30",  // Red
        "#5AC8FA",  // Light Blue
        "#FFCC00",  // Yellow
        "#FF6482",  // Light Pink
        "#30D158",  // Light Green
        "#BF5AF2",  // Light Purple
        "#8E8E93"   // Gray
    ]

    /// Get a random color from the palette
    static var randomColor: String {
        colorPalette.randomElement() ?? "#007AFF"
    }
}
