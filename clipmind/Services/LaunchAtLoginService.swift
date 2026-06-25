//
//  LaunchAtLoginService.swift
//  clipmind
//
//  Service for managing launch at login functionality
//

import Foundation
import ServiceManagement

/// Service to manage launch at login/startup
class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private init() {}

    // MARK: - Public API

    /// Enable or disable launch at login
    func setLaunchAtLogin(enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            return setLaunchAtLoginModern(enabled: enabled)
        } else {
            return setLaunchAtLoginLegacy(enabled: enabled)
        }
    }

    /// Check if launch at login is currently enabled
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return isEnabledModern
        } else {
            return isEnabledLegacy
        }
    }

    // MARK: - Modern Implementation (macOS 13+)

    @available(macOS 13.0, *)
    private func setLaunchAtLoginModern(enabled: Bool) -> Bool {
        do {
            if enabled {
                // Register the app to launch at login
                try SMAppService.mainApp.register()
            } else {
                // Unregister from launching at login
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            return false
        }
    }

    @available(macOS 13.0, *)
    private var isEnabledModern: Bool {
        return SMAppService.mainApp.status == .enabled
    }

    // MARK: - Legacy Implementation (macOS 10.15 - 12.x)

    private func setLaunchAtLoginLegacy(enabled: Bool) -> Bool {
        // For macOS versions before 13.0, we use LSSharedFileList
        // This requires adding the app to Login Items via AppleScript or manual configuration

        // Note: SMLoginItemSetEnabled was deprecated in macOS 13.0
        // For legacy support, we'd need to use LSSharedFileList which is complex
        // For now, we'll just return false and recommend manual setup

        print("Launch at login configuration requires manual setup on macOS < 13.0")
        print("Please add ClipMind to System Preferences > Users & Groups > Login Items")
        return false
    }

    private var isEnabledLegacy: Bool {
        // Cannot reliably check on legacy systems without LSSharedFileList
        return false
    }
}
