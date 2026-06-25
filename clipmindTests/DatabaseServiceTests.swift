//
//  DatabaseServiceTests.swift
//  clipmindTests
//
//  Unit tests for DatabaseService
//

import XCTest
@testable import clipmind

final class DatabaseServiceTests: XCTestCase {
    var databaseService: DatabaseService!

    override func setUpWithError() throws {
        // Use in-memory database for testing
        databaseService = DatabaseService.shared
    }

    override func tearDownWithError() throws {
        // Clean up database after each test
        _ = databaseService.clearAllClipboardItems()
    }

    // MARK: - Clipboard Item Tests

    func testSaveClipboardItem() throws {
        // Given
        let item = ClipboardItem(
            content: .text("Test clipboard content"),
            type: .text,
            timestamp: Date(),
            sourceApp: "Test App"
        )

        // When
        let result = databaseService.saveClipboardItem(item)

        // Then
        XCTAssertTrue(result, "Should successfully save clipboard item")
    }

    func testFetchAllClipboardItems() throws {
        // Given
        let items = [
            ClipboardItem(content: .text("Item 1"), type: .text, timestamp: Date(), sourceApp: "App1"),
            ClipboardItem(content: .text("Item 2"), type: .text, timestamp: Date(), sourceApp: "App2"),
            ClipboardItem(content: .text("Item 3"), type: .text, timestamp: Date(), sourceApp: "App3")
        ]

        items.forEach { _ = databaseService.saveClipboardItem($0) }

        // When
        let fetchedItems = databaseService.fetchAllClipboardItems()

        // Then
        XCTAssertEqual(fetchedItems.count, items.count, "Should fetch all saved items")
    }

    func testFetchClipboardItemsWithPagination() throws {
        // Given - Save 50 items
        for i in 1...50 {
            let item = ClipboardItem(
                content: .text("Item \(i)"),
                type: .text,
                timestamp: Date().addingTimeInterval(TimeInterval(i)),
                sourceApp: "App\(i)"
            )
            _ = databaseService.saveClipboardItem(item)
        }

        // When - Fetch first page
        let page1 = databaseService.fetchClipboardItems(limit: 10, offset: 0)
        let page2 = databaseService.fetchClipboardItems(limit: 10, offset: 10)

        // Then
        XCTAssertEqual(page1.count, 10, "First page should have 10 items")
        XCTAssertEqual(page2.count, 10, "Second page should have 10 items")
        XCTAssertNotEqual(page1.first?.id, page2.first?.id, "Pages should have different items")
    }

    func testGetClipboardItemCount() throws {
        // Given
        for i in 1...25 {
            let item = ClipboardItem(
                content: .text("Item \(i)"),
                type: .text,
                timestamp: Date(),
                sourceApp: "App"
            )
            _ = databaseService.saveClipboardItem(item)
        }

        // When
        let count = databaseService.getClipboardItemCount()

        // Then
        XCTAssertEqual(count, 25, "Should return correct item count")
    }

    func testDeleteClipboardItem() throws {
        // Given
        let item = ClipboardItem(
            content: .text("Item to delete"),
            type: .text,
            timestamp: Date(),
            sourceApp: "App"
        )
        _ = databaseService.saveClipboardItem(item)

        // When
        let result = databaseService.deleteClipboardItem(item.id)

        // Then
        XCTAssertTrue(result, "Should successfully delete item")

        let items = databaseService.fetchAllClipboardItems()
        XCTAssertFalse(items.contains(where: { $0.id == item.id }), "Deleted item should not be in database")
    }

    func testUpdateClipboardItemWorkspace() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace", color: "#FF0000")
        _ = databaseService.saveWorkspace(workspace)

        let item = ClipboardItem(
            content: .text("Test item"),
            type: .text,
            timestamp: Date(),
            sourceApp: "App"
        )
        _ = databaseService.saveClipboardItem(item)

        // When
        let result = databaseService.updateClipboardItemWorkspace(item.id, workspaceId: workspace.id)

        // Then
        XCTAssertTrue(result, "Should successfully update workspace")
    }

    // MARK: - Workspace Tests

    func testSaveWorkspace() throws {
        // Given
        let workspace = Workspace(
            name: "Development",
            color: "#007AFF",
            appFilter: ["Xcode", "Terminal"]
        )

        // When
        let result = databaseService.saveWorkspace(workspace)

        // Then
        XCTAssertTrue(result, "Should successfully save workspace")
    }

    func testFetchAllWorkspaces() throws {
        // Given
        let workspaces = [
            Workspace(name: "Work", color: "#FF0000"),
            Workspace(name: "Personal", color: "#00FF00"),
            Workspace(name: "Development", color: "#0000FF")
        ]

        workspaces.forEach { _ = databaseService.saveWorkspace($0) }

        // When
        let fetchedWorkspaces = databaseService.fetchAllWorkspaces()

        // Then
        XCTAssertEqual(fetchedWorkspaces.count, workspaces.count, "Should fetch all workspaces")
    }

    func testDeleteWorkspace() throws {
        // Given
        let workspace = Workspace(name: "Temporary", color: "#FF00FF")
        _ = databaseService.saveWorkspace(workspace)

        // When
        let result = databaseService.deleteWorkspace(workspace.id)

        // Then
        XCTAssertTrue(result, "Should successfully delete workspace")

        let workspaces = databaseService.fetchAllWorkspaces()
        XCTAssertFalse(workspaces.contains(where: { $0.id == workspace.id }), "Deleted workspace should not exist")
    }

    // MARK: - Performance Tests

    func testDatabasePerformanceLargeInsert() throws {
        measure {
            // Insert 100 items
            for i in 1...100 {
                let item = ClipboardItem(
                    content: .text("Performance test item \(i)"),
                    type: .text,
                    timestamp: Date(),
                    sourceApp: "PerfTest"
                )
                _ = databaseService.saveClipboardItem(item)
            }
        }
    }

    func testDatabasePerformanceLargeFetch() throws {
        // Given - Insert 1000 items
        for i in 1...1000 {
            let item = ClipboardItem(
                content: .text("Item \(i)"),
                type: .text,
                timestamp: Date(),
                sourceApp: "App"
            )
            _ = databaseService.saveClipboardItem(item)
        }

        // When - Measure fetch performance
        measure {
            _ = databaseService.fetchAllClipboardItems()
        }
    }

    func testGetDatabaseStats() throws {
        // Given
        for i in 1...10 {
            let item = ClipboardItem(
                content: .text("Item \(i)"),
                type: .text,
                timestamp: Date(),
                sourceApp: "App"
            )
            _ = databaseService.saveClipboardItem(item)
        }

        // When
        let stats = databaseService.getDatabaseStats()

        // Then
        XCTAssertEqual(stats.totalItems, 10, "Stats should show 10 items")
        XCTAssertGreaterThan(stats.fileSizeBytes, 0, "Database should have non-zero size")
    }
}
