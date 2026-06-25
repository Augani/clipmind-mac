//
//  ClipboardManager.swift
//  clipmind
//
//  Manages clipboard operations (copy to clipboard)
//

import AppKit

/// Manager for clipboard operations
class ClipboardManager {
    static let shared = ClipboardManager()

    var onBeforeCopy: (() -> Void)?

    private init() {}

    /// Copy clipboard item to pasteboard
    func copyToClipboard(_ item: ClipboardItem) {
        onBeforeCopy?()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)

        case .image(let imageData):
            if let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            }

        case .file(let url):
            pasteboard.writeObjects([url as NSURL])

        case .url(let url):
            pasteboard.setString(url.absoluteString, forType: .string)
        }
    }

    /// Copy raw text to pasteboard
    func copyTextToClipboard(_ text: String) {
        onBeforeCopy?()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Get string content from clipboard item
    func getStringContent(_ item: ClipboardItem) -> String? {
        switch item.content {
        case .text(let text):
            return text
        case .url(let url):
            return url.absoluteString
        case .file(let url):
            return url.path
        case .image:
            return nil
        }
    }
}
