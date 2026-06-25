//
//  MultiPasteService.swift
//  clipmind
//
//  Service for pasting multiple clipboard items sequentially
//

import SwiftUI
import AppKit
import Combine
import Carbon.HIToolbox

/// Service for managing multi-paste operations
class MultiPasteService: ObservableObject {
    static let shared = MultiPasteService()

    @Published private(set) var isPasting = false
    @Published private(set) var currentProgress: Double = 0
    @Published private(set) var totalItems: Int = 0
    @Published private(set) var currentItemIndex: Int = 0
    @Published var pasteDelay: TimeInterval = 0.1 // 100ms default

    private var pasteQueue: [ClipboardItem] = []
    private var cancellables = Set<AnyCancellable>()
    private var pasteCancellable: AnyCancellable?

    private init() {
        // Load saved delay from UserDefaults
        if let savedDelay = UserDefaults.standard.object(forKey: "multiPasteDelay") as? Double {
            pasteDelay = savedDelay
        }
    }

    /// Queue items for multi-paste operation
    func queueItems(_ items: [ClipboardItem]) {
        guard !items.isEmpty else { return }
        pasteQueue = items
        totalItems = items.count
        currentItemIndex = 0
        currentProgress = 0
    }

    /// Start pasting queued items
    func startPasting(delay: TimeInterval? = nil) {
        guard !pasteQueue.isEmpty else { return }
        guard !isPasting else { return }

        isPasting = true
        let pasteInterval = delay ?? pasteDelay

        // Cancel any existing paste operation
        pasteCancellable?.cancel()

        // Create a timer publisher for sequential pasting
        pasteCancellable = Timer.publish(every: pasteInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.pasteNextItem()
            }
    }

    /// Paste the next item in the queue
    private func pasteNextItem() {
        guard currentItemIndex < pasteQueue.count else {
            finishPasting()
            return
        }

        let item = pasteQueue[currentItemIndex]

        // Copy item to pasteboard
        ClipboardManager.shared.copyToClipboard(item)

        // Simulate paste command (Cmd+V)
        simulatePasteCommand()

        // Update progress
        currentItemIndex += 1
        currentProgress = Double(currentItemIndex) / Double(totalItems)

        // Check if we're done
        if currentItemIndex >= pasteQueue.count {
            finishPasting()
        }
    }

    /// Simulate Cmd+V keyboard shortcut
    private func simulatePasteCommand() {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Create key down event for Cmd+V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = CGEventFlags.maskCommand
        keyDown?.post(tap: CGEventTapLocation.cghidEventTap)

        // Create key up event
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = CGEventFlags.maskCommand
        keyUp?.post(tap: CGEventTapLocation.cghidEventTap)
    }

    /// Cancel the current paste operation
    func cancelPasting() {
        pasteCancellable?.cancel()
        pasteCancellable = nil
        isPasting = false
        pasteQueue.removeAll()
        currentProgress = 0
        currentItemIndex = 0
        totalItems = 0
    }

    /// Finish the paste operation
    private func finishPasting() {
        pasteCancellable?.cancel()
        pasteCancellable = nil
        isPasting = false
        pasteQueue.removeAll()
        currentProgress = 1.0

        // Reset after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.currentProgress = 0
            self?.currentItemIndex = 0
            self?.totalItems = 0
        }
    }

    /// Update paste delay and save to UserDefaults
    func updatePasteDelay(_ delay: TimeInterval) {
        pasteDelay = delay
        UserDefaults.standard.set(delay, forKey: "multiPasteDelay")
    }

    /// Get progress text for display
    var progressText: String {
        if isPasting {
            return "Pasting \(currentItemIndex + 1) of \(totalItems)"
        } else if totalItems > 0 {
            return "Ready to paste \(totalItems) items"
        } else {
            return ""
        }
    }
}