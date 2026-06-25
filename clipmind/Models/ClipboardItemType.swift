//
//  ClipboardItemType.swift
//  clipmind
//
//  Enum defining clipboard content types
//

import SwiftUI

/// Enum for clipboard item types with display properties
enum ClipboardItemType: String, Codable, CaseIterable {
    case text
    case image
    case code
    case url
    case file

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .code: return "Code"
        case .url: return "URL"
        case .file: return "File"
        }
    }

    var icon: String {
        switch self {
        case .text: return "doc.text.fill"
        case .image: return "photo.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .url: return "link"
        case .file: return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .text: return DesignTokens.Colors.badgeText
        case .image: return DesignTokens.Colors.badgeImage
        case .code: return DesignTokens.Colors.badgeCode
        case .url: return DesignTokens.Colors.badgeURL
        case .file: return DesignTokens.Colors.badgeFile
        }
    }

    /// Detect content type from clipboard content
    static func detect(from content: ClipboardContent) -> ClipboardItemType {
        switch content {
        case .text(let text):
            // Check if it looks like code
            if isCodeLike(text) {
                return .code
            }
            return .text
        case .image:
            return .image
        case .file:
            return .file
        case .url:
            return .url
        }
    }

    /// Simple heuristic to detect if text is code
    private static func isCodeLike(_ text: String) -> Bool {
        let codeIndicators = [
            "func ", "class ", "struct ", "import ", "const ", "let ", "var ",
            "def ", "public ", "private ", "protected ", "override ",
            "{", "}", "()", "=>", "function"
        ]

        let lowercased = text.lowercased()
        let matches = codeIndicators.filter { lowercased.contains($0) }

        // If text contains multiple code indicators, it's likely code
        return matches.count >= 2
    }
}
