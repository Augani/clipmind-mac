//
//  WorkspaceServiceTests.swift
//  clipmindTests
//
//  Unit tests for WorkspaceService
//

import XCTest
@testable import clipmind

final class WorkspaceServiceTests: XCTestCase {
    var workspaceService: WorkspaceService!
    var databaseService: DatabaseService!

    override func setUpWithError() throws {
        databaseService = DatabaseService.shared
        workspaceService = WorkspaceService(database: databaseService)

        // Clean up before each test
        _ = databaseService.clearAllClipboardItems()
    }

    // MARK: - Workspace CRUD Tests

    func testCreateWorkspace() throws {
        // Given
        let name = "Development"
        let color = "#007AFF"

        // When
        let workspace = workspaceService.createWorkspace(name: name, color: color)

        // Then
        XCTAssertEqual(workspace.name, name)
        XCTAssertEqual(workspace.color, color)
        XCTAssertTrue(workspaceService.workspaces.contains(where: { $0.id == workspace.id }))
    }

    func testUpdateWorkspace() throws {
        // Given
        let workspace = workspaceService.createWorkspace(name: "Work", color: "#FF0000")
        let newName = "Personal Work"
        let newColor = "#00FF00"

        // When
        workspaceService.updateWorkspace(
            workspace,
            name: newName,
            color: newColor,
            appFilter: ["Xcode", "Terminal"]
        )

        // Then
        let updated = workspaceService.workspaces.first { $0.id == workspace.id }
        XCTAssertEqual(updated?.name, newName)
        XCTAssertEqual(updated?.color, newColor)
        XCTAssertEqual(updated?.appFilter, ["Xcode", "Terminal"])
    }

    func testDeleteWorkspace() throws {
        // Given
        let workspace = workspaceService.createWorkspace(name: "Temporary", color: "#FF00FF")

        // When
        workspaceService.deleteWorkspace(workspace)

        // Then
        XCTAssertFalse(workspaceService.workspaces.contains(where: { $0.id == workspace.id }))
    }

    // MARK: - Workspace Assignment Tests

    func testShouldAutoAssignWorkspace() throws {
        // Given
        let workspace = workspaceService.createWorkspace(
            name: "Development",
            color: "#007AFF",
            appFilter: ["Xcode", "Terminal", "VSCode"]
        )

        // When
        let shouldAssignXcode = workspaceService.shouldAutoAssign(
            toWorkspace: workspace,
            sourceApp: "Xcode"
        )

        let shouldAssignSafari = workspaceService.shouldAutoAssign(
            toWorkspace: workspace,
            sourceApp: "Safari"
        )

        // Then
        XCTAssertTrue(shouldAssignXcode, "Should auto-assign for Xcode")
        XCTAssertFalse(shouldAssignSafari, "Should not auto-assign for Safari")
    }

    func testGetWorkspaceForApp() throws {
        // Given
        let devWorkspace = workspaceService.createWorkspace(
            name: "Development",
            color: "#007AFF",
            appFilter: ["Xcode"]
        )

        let designWorkspace = workspaceService.createWorkspace(
            name: "Design",
            color: "#FF00FF",
            appFilter: ["Figma", "Sketch"]
        )

        // When
        let xcodeWorkspace = workspaceService.getWorkspaceForApp("Xcode")
        let figmaWorkspace = workspaceService.getWorkspaceForApp("Figma")
        let safariWorkspace = workspaceService.getWorkspaceForApp("Safari")

        // Then
        XCTAssertEqual(xcodeWorkspace?.id, devWorkspace.id)
        XCTAssertEqual(figmaWorkspace?.id, designWorkspace.id)
        XCTAssertNil(safariWorkspace)
    }

    // MARK: - Multiple Workspaces Tests

    func testMultipleWorkspaces() throws {
        // Given
        let workspaces = [
            ("Work", "#FF0000"),
            ("Personal", "#00FF00"),
            ("Development", "#0000FF"),
            ("Design", "#FF00FF")
        ]

        // When
        workspaces.forEach { name, color in
            _ = workspaceService.createWorkspace(name: name, color: color)
        }

        // Then
        XCTAssertEqual(workspaceService.workspaces.count, workspaces.count)
    }

    func testWorkspaceOrdering() throws {
        // Given
        let workspace1 = workspaceService.createWorkspace(name: "First", color: "#FF0000")
        Thread.sleep(forTimeInterval: 0.1)
        let workspace2 = workspaceService.createWorkspace(name: "Second", color: "#00FF00")
        Thread.sleep(forTimeInterval: 0.1)
        let workspace3 = workspaceService.createWorkspace(name: "Third", color: "#0000FF")

        // When
        let workspaces = workspaceService.workspaces

        // Then
        XCTAssertEqual(workspaces[0].id, workspace1.id)
        XCTAssertEqual(workspaces[1].id, workspace2.id)
        XCTAssertEqual(workspaces[2].id, workspace3.id)
    }

    // MARK: - App Filter Tests

    func testEmptyAppFilter() throws {
        // Given
        let workspace = workspaceService.createWorkspace(
            name: "General",
            color: "#8E8E93",
            appFilter: []
        )

        // When
        let shouldAssign = workspaceService.shouldAutoAssign(
            toWorkspace: workspace,
            sourceApp: "AnyApp"
        )

        // Then
        XCTAssertFalse(shouldAssign, "Empty app filter should not auto-assign")
    }

    func testCaseInsensitiveAppFilter() throws {
        // Given
        let workspace = workspaceService.createWorkspace(
            name: "Development",
            color: "#007AFF",
            appFilter: ["xcode", "terminal"]
        )

        // When
        let shouldAssignUppercase = workspaceService.shouldAutoAssign(
            toWorkspace: workspace,
            sourceApp: "Xcode"
        )

        let shouldAssignLowercase = workspaceService.shouldAutoAssign(
            toWorkspace: workspace,
            sourceApp: "terminal"
        )

        // Then
        XCTAssertTrue(shouldAssignUppercase, "Should be case-insensitive for uppercase")
        XCTAssertTrue(shouldAssignLowercase, "Should be case-insensitive for lowercase")
    }

    // MARK: - Performance Tests

    func testWorkspaceCreationPerformance() throws {
        measure {
            for i in 1...100 {
                _ = workspaceService.createWorkspace(
                    name: "Workspace \(i)",
                    color: "#\(String(format: "%06X", i % 0xFFFFFF))"
                )
            }

            // Cleanup
            workspaceService.workspaces.forEach { workspaceService.deleteWorkspace($0) }
        }
    }

    func testGetWorkspaceForAppPerformance() throws {
        // Given
        for i in 1...50 {
            _ = workspaceService.createWorkspace(
                name: "Workspace \(i)",
                color: "#000000",
                appFilter: ["App\(i)"]
            )
        }

        // When/Then
        measure {
            for i in 1...100 {
                _ = workspaceService.getWorkspaceForApp("App\(i % 50)")
            }
        }
    }
}
