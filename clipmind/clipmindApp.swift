//
//  clipmindApp.swift
//  clipmind
//
//  Created by Augustus Otu on 08/11/2025.
//

import SwiftUI
import Combine

@main
struct clipmindApp: App {
    @StateObject private var clipboardStore = ClipboardStore()
    @StateObject private var windowManager = WindowManager()
    private let hotkeyService = HotkeyService.shared
    private let floatingSearchManager = FloatingSearchManager.shared

    init() {
        // Hide dock icon to make this a menu bar-only app
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        // Menu bar popover
        MenuBarExtra {
            ClipboardMenuPopoverWrapper(clipboardStore: clipboardStore, windowManager: windowManager)
                .onAppear {
                    // Start clipboard monitoring when menu bar appears
                    clipboardStore.startMonitoring()

                    NotchHUDController.shared.start(
                        observing: clipboardStore,
                        isEnabled: { UserDefaults.standard.object(forKey: "notchHUDEnabled") as? Bool ?? true }
                    )

                    // Setup global hotkey for floating search
                    _ = hotkeyService.registerHotkey { [clipboardStore] in
                        FloatingSearchManager.shared.showFloatingSearch(clipboardStore: clipboardStore)
                    }

                    // Check for accessibility permissions
                    if !MetadataExtractor.shared.checkAccessibilityPermissions() {
                        // Request permissions on first launch
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            MetadataExtractor.shared.requestAccessibilityPermissions()
                        }
                    }
                }
        } label: {
            Image("MenuBarGlyph")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)

        // Main dashboard window
        WindowGroup("ClipMind", id: "main-dashboard") {
            DashboardView()
                .environmentObject(clipboardStore)
                .onAppear {
                    // Store window reference for later use
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main-dashboard" }) {
                        windowManager.mainWindow = window
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "main-dashboard"))

        // Settings window
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(clipboardStore)
        }
        #endif
    }
}

// MARK: - Window Manager

class WindowManager: ObservableObject {
    @Published var mainWindow: NSWindow?

    func openMainWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApp.windows.first(where: {
                    $0.title.contains("ClipMind") ||
                    ($0.identifier?.rawValue.contains("main-dashboard") ?? false)
                }) {
                    window.makeKeyAndOrderFront(nil)
                    self.mainWindow = window
                }
            }
        }
    }
}

// MARK: - Menu Bar Popover Wrapper

struct ClipboardMenuPopoverWrapper: View {
    @ObservedObject var clipboardStore: ClipboardStore
    @ObservedObject var windowManager: WindowManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ClipboardMenuPopover(
            onOpenMainWindow: {
                dismissMenuBar()
                openWindow(id: "main-dashboard")
                windowManager.openMainWindow()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            },
            onClose: {
                dismissMenuBar()
            }
        )
        .environmentObject(clipboardStore)
    }

    private func dismissMenuBar() {
        let menuWindows = NSApp.windows.filter { $0.className.contains("MenuBarExtra") }
        if menuWindows.isEmpty {
            NSApp.keyWindow?.close()
        } else {
            menuWindows.forEach { $0.close() }
        }
    }
}

