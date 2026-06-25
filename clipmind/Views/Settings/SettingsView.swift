//
//  SettingsView.swift
//  clipmind
//
//  Settings view with tabs for all configuration options
//

import SwiftUI
import Carbon.HIToolbox

struct SettingsView: View {
    @EnvironmentObject var clipboardStore: ClipboardStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            HotkeySettingsView()
                .tabItem {
                    Label("Hotkeys", systemImage: "command.square")
                }
                .tag(1)

            SecuritySettingsView()
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }
                .tag(2)

            MultiPasteSettingsView()
                .tabItem {
                    Label("Multi-Paste", systemImage: "doc.on.doc")
                }
                .tag(3)

            CleanupSettingsView()
                .tabItem {
                    Label("Cleanup", systemImage: "trash.circle")
                }
                .tag(4)

            iCloudSyncView()
                .tabItem {
                    Label("iCloud Sync", systemImage: "icloud")
                }
                .tag(5)

            AutoTaggingView()
                .tabItem {
                    Label("Auto-Tagging", systemImage: "tag")
                }
                .tag(6)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(7)
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var clipboardStore: ClipboardStore
    @AppStorage("maxClipboardItems") private var maxItems = 1000
    @AppStorage("launchAtStartup") private var launchAtStartup = false
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("notchHUDEnabled") private var notchHUDEnabled = true
    @AppStorage("autoDeleteEnabled") private var autoDeleteEnabled = false
    @AppStorage("autoDeleteDays") private var autoDeleteDays = 30
    @State private var showLaunchAtLoginError = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at startup", isOn: $launchAtStartup)
                    .onChange(of: launchAtStartup) { newValue in
                        let success = LaunchAtLoginService.shared.setLaunchAtLogin(enabled: newValue)
                        if !success {
                            launchAtStartup = !newValue
                            showLaunchAtLoginError = true
                        }
                    }

                Toggle("Show in Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { newValue in
                        NSApplication.shared.setActivationPolicy(newValue ? .regular : .accessory)
                    }

                Toggle("Show capture notification near the notch", isOn: $notchHUDEnabled)

                Toggle("Automatically delete old copies", isOn: $autoDeleteEnabled)

                if autoDeleteEnabled {
                    HStack {
                        Text("Delete copies older than:")
                        TextField("", value: $autoDeleteDays, format: .number)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                        Text("days")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Maximum clipboard items:")
                    TextField("", value: $maxItems, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("(100-10000)")
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Text("Items stored: \(clipboardStore.items.count)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear All") {
                        clipboardStore.clearAll()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Launch at Login", isPresented: $showLaunchAtLoginError) {
            Button("OK", role: .cancel) {
                showLaunchAtLoginError = false
            }
        } message: {
            Text("Failed to configure launch at login. On macOS versions before 13.0, please add ClipMind manually to System Preferences > Users & Groups > Login Items.")
        }
    }
}

// MARK: - Hotkey Settings

struct HotkeySettingsView: View {
    @EnvironmentObject var clipboardStore: ClipboardStore
    @StateObject private var hotkeyService = HotkeyService.shared
    @State private var isRecordingHotkey = false
    @State private var recordedKeyCode: Int?
    @State private var recordedModifiers: Int?
    @AppStorage("hotkey_keycode") private var storedKeyCode: Int = kVK_ANSI_V
    @AppStorage("hotkey_modifiers") private var storedModifiers: Int = Int(cmdKey | shiftKey)

    var currentHotkeyDescription: String {
        HotkeyService.hotkeyDescription(keyCode: storedKeyCode, modifiers: storedModifiers)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Global Hotkey for Search Panel")
                        .headlineSmall()

                    HStack {
                        Text("Current hotkey:")
                            .bodyMedium()
                        Text(currentHotkeyDescription)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)

                        Spacer()

                        if isRecordingHotkey {
                            Button("Cancel") {
                                isRecordingHotkey = false
                                recordedKeyCode = nil
                                recordedModifiers = nil
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Change") {
                                isRecordingHotkey = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if isRecordingHotkey {
                        Text("Press your desired hotkey combination...")
                            .bodySmall()
                            .italic()
                    }

                    if let keyCode = recordedKeyCode, let modifiers = recordedModifiers {
                        HStack {
                            Text("New hotkey: \(HotkeyService.hotkeyDescription(keyCode: keyCode, modifiers: modifiers))")
                                .bodyMedium()
                            Spacer()
                            Button("Apply") {
                                applyNewHotkey(keyCode: keyCode, modifiers: modifiers)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 8)
                    }

                    Divider()

                    Text("Recommended hotkeys:")
                        .labelMedium()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• ⌘⇧V - Command+Shift+V (default)")
                        Text("• ⌘⌥V - Command+Option+V")
                        Text("• ⌃⌘V - Control+Command+V")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func applyNewHotkey(keyCode: Int, modifiers: Int) {
        let success = hotkeyService.registerHotkey(keyCode: keyCode, modifiers: modifiers) { [weak clipboardStore] in
            guard let store = clipboardStore else { return }
            FloatingSearchManager.shared.showFloatingSearch(clipboardStore: store)
        }

        if success {
            storedKeyCode = keyCode
            storedModifiers = modifiers
            isRecordingHotkey = false
            recordedKeyCode = nil
            recordedModifiers = nil
        }
    }
}

// MARK: - Security Settings

struct SecuritySettingsView: View {
    @StateObject private var securityService = SecurityService.shared

    var body: some View {
        Form {
            Section("Sensitive Content Detection") {
                Toggle("Auto-detect sensitive content", isOn: $securityService.isAutoDetectionEnabled)

                Toggle("Encrypt sensitive items", isOn: $securityService.encryptSensitiveItems)
                    .disabled(!securityService.isAutoDetectionEnabled)

                HStack {
                    Text("Auto-delete sensitive items after:")
                    Picker("", selection: $securityService.autoDeleteSensitiveHours) {
                        Text("Never").tag(0)
                        Text("1 hour").tag(1)
                        Text("6 hours").tag(6)
                        Text("12 hours").tag(12)
                        Text("24 hours").tag(24)
                        Text("48 hours").tag(48)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Toggle("Incognito Mode", isOn: $securityService.isIncognitoMode)
                    .help("Temporarily disable clipboard monitoring")

                if securityService.isIncognitoMode {
                    Label("Clipboard monitoring is paused", systemImage: "eye.slash")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            Section("Excluded Applications") {
                Text("Apps excluded from clipboard monitoring:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if securityService.excludedApps.isEmpty {
                            Text("No excluded apps")
                                .foregroundStyle(.tertiary)
                                .italic()
                        } else {
                            ForEach(Array(securityService.excludedApps), id: \.self) { app in
                                HStack {
                                    Image(systemName: "app")
                                        .foregroundStyle(.secondary)
                                    Text(app)
                                        .font(.system(size: 11))
                                    Spacer()
                                    Button {
                                        securityService.excludedApps.remove(app)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .frame(maxHeight: 100)

                HStack {
                    TextField("Bundle ID (e.g., com.apple.Terminal)", text: .constant(""))
                    Button("Add") {
                        // Add app to excluded list
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Detected Patterns") {
                Text("The following patterns are detected as sensitive:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(["API Keys", "Credit Cards", "SSN", "Passwords", "Private Keys", "Database URLs", "JWT Tokens"], id: \.self) { pattern in
                            Label(pattern, systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Multi-Paste Settings

struct MultiPasteSettingsView: View {
    @StateObject private var multiPasteService = MultiPasteService.shared
    @State private var testDelay: TimeInterval = 0.1

    var body: some View {
        Form {
            Section("Multi-Paste Configuration") {
                HStack {
                    Text("Paste delay between items:")
                        .bodyMedium()
                    Slider(value: $multiPasteService.pasteDelay, in: 0.05...0.5, step: 0.05)
                        .frame(width: 150)
                    Text("\(Int(multiPasteService.pasteDelay * 1000))ms")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 60, alignment: .trailing)
                }

                HStack {
                    Text("Recommended: 100-200ms for reliability")
                        .caption()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("How Multi-Paste Works:")
                        .headlineSmall()

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Select multiple items in the dashboard", systemImage: "1.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label("Click 'Paste Selected' button", systemImage: "2.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label("Items are pasted in order with delay", systemImage: "3.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label("Use ⌘+Click for multi-selection", systemImage: "4.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if multiPasteService.isPasting {
                    HStack {
                        ProgressView(value: multiPasteService.currentProgress)
                        Text(multiPasteService.progressText)
                            .font(.caption)
                        Button("Cancel") {
                            multiPasteService.cancelPasting()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            AppLogoWithText(logoSize: .xlarge)

            Text("Version 1.0.0")
                .bodyMedium()

            VStack(alignment: .leading, spacing: 8) {
                Text("Features:")
                    .headlineSmall()

                VStack(alignment: .leading, spacing: 4) {
                    Label("Smart clipboard history", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Workspace organization", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Global hotkey access", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Multi-paste support", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Security & privacy", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("© 2024 ClipMind. All rights reserved.")
                .caption()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
    }
}