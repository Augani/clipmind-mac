//
//  ClipboardItem.swift
//  clipmind
//
//  Core data model for clipboard items
//

import SwiftUI
import AppKit

enum ClipboardOrigin: String, Codable {
    case local
    case universalClipboard

    var displayName: String {
        switch self {
        case .local: return "This Mac"
        case .universalClipboard: return "iPhone / iPad"
        }
    }

    var deviceSymbolName: String? {
        switch self {
        case .local: return nil
        case .universalClipboard: return "iphone"
        }
    }
}

/// Represents a single clipboard item with rich metadata
struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: ClipboardContent
    let type: ClipboardItemType
    let timestamp: Date
    let sourceApp: String
    let sourceBundleIdentifier: String?
    let windowTitle: String?
    var workspaceId: UUID?
    var isMarkedSensitive: Bool = false
    var encryptedContent: Data? = nil
    var sensitiveContentTypes: Set<String> = []
    var activityContext: ActivityContext?
    var origin: ClipboardOrigin = .local

    init(
        id: UUID = UUID(),
        content: ClipboardContent,
        type: ClipboardItemType,
        timestamp: Date = Date(),
        sourceApp: String,
        sourceBundleIdentifier: String? = nil,
        windowTitle: String? = nil,
        workspaceId: UUID? = nil,
        isMarkedSensitive: Bool = false,
        encryptedContent: Data? = nil,
        sensitiveContentTypes: Set<String> = [],
        activityContext: ActivityContext? = nil,
        origin: ClipboardOrigin = .local
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.sourceApp = sourceApp
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.windowTitle = windowTitle
        self.workspaceId = workspaceId
        self.isMarkedSensitive = isMarkedSensitive
        self.encryptedContent = encryptedContent
        self.sensitiveContentTypes = sensitiveContentTypes
        self.activityContext = activityContext
        self.origin = origin
    }

    enum CodingKeys: String, CodingKey {
        case id, content, type, timestamp, sourceApp, sourceBundleIdentifier, windowTitle, workspaceId, isMarkedSensitive, encryptedContent, sensitiveContentTypes, activityContext, origin
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        content = try c.decode(ClipboardContent.self, forKey: .content)
        type = try c.decode(ClipboardItemType.self, forKey: .type)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        sourceApp = try c.decode(String.self, forKey: .sourceApp)
        sourceBundleIdentifier = try c.decodeIfPresent(String.self, forKey: .sourceBundleIdentifier)
        windowTitle = try c.decodeIfPresent(String.self, forKey: .windowTitle)
        workspaceId = try c.decodeIfPresent(UUID.self, forKey: .workspaceId)
        isMarkedSensitive = try c.decodeIfPresent(Bool.self, forKey: .isMarkedSensitive) ?? false
        encryptedContent = try c.decodeIfPresent(Data.self, forKey: .encryptedContent)
        sensitiveContentTypes = try c.decodeIfPresent(Set<String>.self, forKey: .sensitiveContentTypes) ?? []
        activityContext = try c.decodeIfPresent(ActivityContext.self, forKey: .activityContext)
        origin = try c.decodeIfPresent(ClipboardOrigin.self, forKey: .origin) ?? .local
    }

    /// Preview text for displaying in UI
    var previewText: String {
        switch content {
        case .text(let text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .image:
            return "[Image]"
        case .file(let url):
            return url.lastPathComponent
        case .url(let url):
            return url.absoluteString
        }
    }

    /// First line of content for compact display
    var firstLine: String {
        let preview = previewText
        if let firstLineText = preview.components(separatedBy: .newlines).first {
            return firstLineText
        }
        return preview
    }

    /// Count of lines in text content
    var lineCount: Int {
        let preview = previewText
        return preview.components(separatedBy: .newlines).count
    }

    /// Truncated preview with max length
    func truncatedPreview(maxLength: Int = 100) -> String {
        let preview = firstLine
        if preview.count > maxLength {
            return String(preview.prefix(maxLength)) + "..."
        }
        return preview
    }

    // MARK: - Activity Context Helpers

    var timeCategory: TimeCategory {
        activityContext?.timeCategory ?? TimeCategory.from(date: timestamp)
    }

    var dayCategory: DayCategory {
        activityContext?.dayCategory ?? DayCategory.from(date: timestamp)
    }

    var wasFromBrowser: Bool {
        activityContext?.isFromBrowser ?? false
    }

    var wasFromCodeEditor: Bool {
        activityContext?.isFromCodeEditor ?? false
    }

    var gitBranch: String? {
        activityContext?.gitBranch
    }

    var projectPath: String? {
        activityContext?.projectPath
    }

    var browserUrl: String? {
        activityContext?.browserTabUrl
    }

    var browserTitle: String? {
        activityContext?.browserTabTitle
    }

    var activitySessionId: UUID? {
        activityContext?.activitySessionId
    }

    var isFromToday: Bool {
        Calendar.current.isDateInToday(timestamp)
    }

    var isFromYesterday: Bool {
        Calendar.current.isDateInYesterday(timestamp)
    }

    var isFromThisWeek: Bool {
        Calendar.current.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var contextDescription: String {
        activityContext?.contextDescription ?? "\(timeCategory.displayName)"
    }
}

/// Enum representing clipboard content types
enum ClipboardContent: Codable, Equatable {
    case text(String)
    case image(Data)  // PNG data
    case file(URL)
    case url(URL)

    // Custom coding to handle different types
    enum CodingKeys: String, CodingKey {
        case type, value
    }

    enum ContentType: String, Codable {
        case text, image, file, url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)

        switch type {
        case .text:
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case .image:
            let value = try container.decode(Data.self, forKey: .value)
            self = .image(value)
        case .file:
            let value = try container.decode(URL.self, forKey: .value)
            self = .file(value)
        case .url:
            let value = try container.decode(URL.self, forKey: .value)
            self = .url(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let value):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case .image(let value):
            try container.encode(ContentType.image, forKey: .type)
            try container.encode(value, forKey: .value)
        case .file(let value):
            try container.encode(ContentType.file, forKey: .type)
            try container.encode(value, forKey: .value)
        case .url(let value):
            try container.encode(ContentType.url, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

// MARK: - Sample Data for Previews

extension ClipboardItem {
    static var sampleText: ClipboardItem {
        ClipboardItem(
            content: .text("func calculateTotal() -> Double {\n    return items.reduce(0) { $0 + $1.price }\n}"),
            type: .code,
            timestamp: Date().addingTimeInterval(-120),
            sourceApp: "Xcode",
            sourceBundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "ClipboardItem.swift",
            activityContext: ActivityContext(
                timeCategory: .morning,
                dayCategory: .weekday,
                gitBranch: "feature/memory-search",
                projectPath: "/Users/user/Projects/clipmind"
            )
        )
    }

    static var sampleURL: ClipboardItem {
        ClipboardItem(
            content: .url(URL(string: "https://developer.apple.com/documentation/swiftui")!),
            type: .url,
            timestamp: Date().addingTimeInterval(-3600),
            sourceApp: "Safari",
            sourceBundleIdentifier: "com.apple.Safari",
            windowTitle: "SwiftUI Documentation",
            activityContext: ActivityContext(
                timeCategory: .afternoon,
                dayCategory: .weekday,
                browserTabUrl: "https://developer.apple.com/documentation/swiftui",
                browserTabTitle: "SwiftUI Documentation"
            )
        )
    }

    static var sampleImage: ClipboardItem {
        ClipboardItem(
            content: .image(Data()),
            type: .image,
            timestamp: Date().addingTimeInterval(-7200),
            sourceApp: "Preview",
            sourceBundleIdentifier: "com.apple.Preview",
            windowTitle: "screenshot.png",
            activityContext: ActivityContext(
                timeCategory: .evening,
                dayCategory: .weekend
            )
        )
    }

    static var sampleFile: ClipboardItem {
        ClipboardItem(
            content: .file(URL(fileURLWithPath: "/Users/user/Documents/report.pdf")),
            type: .file,
            timestamp: Date().addingTimeInterval(-86400),
            sourceApp: "Finder",
            sourceBundleIdentifier: "com.apple.finder",
            windowTitle: nil,
            activityContext: ActivityContext(
                timeCategory: .night,
                dayCategory: .weekday
            )
        )
    }

    static var samples: [ClipboardItem] {
        [sampleText, sampleURL, sampleImage, sampleFile]
    }
}
