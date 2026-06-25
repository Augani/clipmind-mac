//
//  ClipboardMonitor.swift
//  clipmind
//
//  Monitors NSPasteboard for changes and captures clipboard content
//

import AppKit
import Combine

extension NSPasteboard.PasteboardType {
    static let universalClipboard = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
}

/// Service that monitors clipboard changes and extracts content
class ClipboardMonitor: ObservableObject {
    private var pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    private let idlePollingInterval: TimeInterval = 1.5
    private let activePollingInterval: TimeInterval = 0.3
    private var currentPollingInterval: TimeInterval = 1.5
    private var recentActivityCount: Int = 0
    private var lastActivityTime: Date = .distantPast

    private var ignoredChangeCount: Int?
    private var selfCopyTimestamp: Date?
    private let selfCopyGracePeriod: TimeInterval = 1.0

    private static let appBundleIdentifier = Bundle.main.bundleIdentifier ?? "com.clipmind"

    var onNewClipboardItem: ((ClipboardItem) -> Void)?

    init() {
        self.lastChangeCount = pasteboard.changeCount
    }

    func markNextChangeAsOurs() {
        selfCopyTimestamp = Date()
    }

    func ignoreChangeCount(_ count: Int) {
        ignoredChangeCount = count
    }

    func startMonitoring() {
        stopMonitoring()
        currentPollingInterval = idlePollingInterval
        scheduleTimer()
        checkForChanges()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: currentPollingInterval, repeats: false) { [weak self] _ in
            self?.timerFired()
        }
        timer?.tolerance = currentPollingInterval * 0.2
    }

    private func timerFired() {
        checkForChanges()
        adjustPollingInterval()
        scheduleTimer()
    }

    private func adjustPollingInterval() {
        let timeSinceActivity = Date().timeIntervalSince(lastActivityTime)

        if timeSinceActivity < 5.0 {
            currentPollingInterval = activePollingInterval
        } else if timeSinceActivity < 30.0 {
            currentPollingInterval = 0.75
        } else {
            currentPollingInterval = idlePollingInterval
        }
    }

    /// Stop monitoring clipboard changes
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount

            if shouldIgnoreChange(changeCount: currentChangeCount) {
                ignoredChangeCount = nil
                return
            }

            lastActivityTime = Date()
            recentActivityCount += 1
            handleClipboardChange()
        }
    }

    private func shouldIgnoreChange(changeCount: Int) -> Bool {
        if let ignored = ignoredChangeCount, ignored == changeCount {
            return true
        }

        if let timestamp = selfCopyTimestamp,
           Date().timeIntervalSince(timestamp) < selfCopyGracePeriod {
            selfCopyTimestamp = nil
            return true
        }

        return false
    }

    static func isRemote(types: [NSPasteboard.PasteboardType]) -> Bool {
        types.contains(.universalClipboard)
    }

    private func handleClipboardChange() {
        let isRemote = Self.isRemote(types: pasteboard.types ?? [])
        let metadata = MetadataExtractor.shared.extractExtendedMetadata()

        if !isRemote, metadata.bundleIdentifier == Self.appBundleIdentifier {
            return
        }

        guard let content = extractClipboardContent() else {
            return
        }

        let type = ClipboardItemType.detect(from: content)

        let item = ClipboardItem(
            content: content,
            type: type,
            timestamp: Date(),
            sourceApp: isRemote ? ClipboardOrigin.universalClipboard.displayName : metadata.appName,
            sourceBundleIdentifier: isRemote ? nil : metadata.bundleIdentifier,
            windowTitle: isRemote ? nil : metadata.windowTitle,
            activityContext: isRemote ? nil : metadata.activityContext,
            origin: isRemote ? .universalClipboard : .local
        )

        DispatchQueue.main.async { [weak self] in
            self?.onNewClipboardItem?(item)
        }
    }

    /// Extract content from pasteboard
    private func extractClipboardContent() -> ClipboardContent? {
        // Check for file URLs first
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let firstURL = fileURLs.first,
           firstURL.isFileURL {
            return .file(firstURL)
        }

        // Check for URLs
        if let urlString = pasteboard.string(forType: .URL),
           let url = URL(string: urlString) {
            return .url(url)
        }

        // Check for strings (might be URL text)
        if let string = pasteboard.string(forType: .string) {
            // Check if string is a valid URL
            if let url = URL(string: string), url.scheme != nil {
                return .url(url)
            }
            // Otherwise, treat as text
            return .text(string)
        }

        // Check for images
        if let image = NSImage(pasteboard: pasteboard),
           let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            return .image(pngData)
        }

        return nil
    }

    deinit {
        stopMonitoring()
    }
}
