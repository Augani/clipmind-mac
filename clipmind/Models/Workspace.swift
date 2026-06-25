//
//  Workspace.swift
//  clipmind
//
//  Workspace model for organizing clipboard items by project/context
//

import SwiftUI
import Foundation

/// Represents a workspace for organizing clipboard items
struct Workspace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: String  // Hex color string
    var appFilter: [String]  // Array of bundle IDs for auto-assignment
    var projectPath: String?  // Project directory path for auto-assignment
    var autoTagRules: String?  // JSON string for custom auto-tag rules
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        color: String,
        appFilter: [String] = [],
        projectPath: String? = nil,
        autoTagRules: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.appFilter = appFilter
        self.projectPath = projectPath
        self.autoTagRules = autoTagRules
        self.createdAt = createdAt
    }

    // MARK: - Color Helpers

    /// Convert hex color string to SwiftUI Color
    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }

    /// Convert hex color string to NSColor
    var nsColor: NSColor {
        NSColor(hex: color) ?? .systemBlue
    }

    // MARK: - Matching Logic

    /// Check if a clipboard item should be auto-assigned to this workspace
    func matches(_ item: ClipboardItem) -> Bool {
        // Match by app bundle identifier
        if let bundleId = item.sourceBundleIdentifier,
           appFilter.contains(bundleId) {
            return true
        }

        // Match by project path in window title
        if let projectPath = projectPath,
           !projectPath.isEmpty,
           let windowTitle = item.windowTitle,
           windowTitle.contains(projectPath) {
            return true
        }

        return false
    }
}

// MARK: - Default Workspaces

extension Workspace {
    /// Default "Uncategorized" workspace
    static var uncategorized: Workspace {
        Workspace(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Uncategorized",
            color: "#8E8E93"  // Gray
        )
    }

    /// Sample workspace for previews
    static var sampleDevelopment: Workspace {
        Workspace(
            name: "Development",
            color: "#007AFF",  // Blue
            appFilter: ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.github.GitHubClient"]
        )
    }

    static var sampleDesign: Workspace {
        Workspace(
            name: "Design",
            color: "#FF2D55",  // Pink
            appFilter: ["com.adobe.Photoshop", "com.sketch.Sketch", "com.figma.Desktop"]
        )
    }

    static var sampleResearch: Workspace {
        Workspace(
            name: "Research",
            color: "#34C759",  // Green
            appFilter: ["com.apple.Safari", "org.mozilla.firefox"]
        )
    }

    static var samples: [Workspace] {
        [uncategorized, sampleDevelopment, sampleDesign, sampleResearch]
    }
}

// MARK: - Color Extension

extension Color {
    /// Initialize Color from hex string
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    /// Convert Color to hex string
    var hexString: String {
        guard let components = NSColor(self).cgColor.components else {
            return "#000000"
        }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension NSColor {
    /// Initialize NSColor from hex string
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
