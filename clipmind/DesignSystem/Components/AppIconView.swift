//
//  AppIconView.swift
//  clipmind
//
//  Displays source application icon
//

import SwiftUI
import AppKit

/// View that displays an application icon from bundle identifier
struct AppIconView: View {
    let bundleIdentifier: String?
    let appName: String
    let size: CGFloat
    let origin: ClipboardOrigin

    init(bundleIdentifier: String?, appName: String, size: CGFloat = DesignTokens.Sizes.appIconMD, origin: ClipboardOrigin = .local) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.size = size
        self.origin = origin
    }

    var body: some View {
        Group {
            if let symbol = origin.deviceSymbolName {
                Image(systemName: symbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(0.82)
                    .foregroundStyle(DesignTokens.Colors.accentPrimary)
            } else if let icon = getAppIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback icon
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private func getAppIcon() -> NSImage? {
        guard let bundleIdentifier = bundleIdentifier else { return nil }

        // Try to get app path from bundle identifier
        if let appPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appPath.path)
        }

        return nil
    }
}

#Preview("App Icons") {
    VStack(spacing: 16) {
        // Real app icons (if available on system)
        AppIconView(bundleIdentifier: "com.apple.Safari", appName: "Safari", size: 32)
        AppIconView(bundleIdentifier: "com.apple.finder", appName: "Finder", size: 24)
        AppIconView(bundleIdentifier: "com.unknown.app", appName: "Unknown", size: 20)
    }
    .padding()
}
