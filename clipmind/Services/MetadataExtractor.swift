//
//  MetadataExtractor.swift
//  clipmind
//
//  Extracts metadata about the active application and window
//

import AppKit
import ApplicationServices

struct AppMetadata {
    let appName: String
    let bundleIdentifier: String?
    let windowTitle: String?
}

struct ExtendedAppMetadata {
    let appName: String
    let bundleIdentifier: String?
    let windowTitle: String?
    let activityContext: ActivityContext
}

class MetadataExtractor {
    static let shared = MetadataExtractor()

    private let codeEditorBundleIds: Set<String> = [
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.jetbrains.intellij",
        "com.jetbrains.WebStorm",
        "com.jetbrains.PyCharm",
        "com.jetbrains.CLion",
        "com.jetbrains.AppCode",
        "com.jetbrains.goland",
        "com.jetbrains.rider",
        "com.github.atom",
        "com.googlecode.iterm2",
        "com.apple.Terminal",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "net.kovidgoyal.kitty",
        "com.todesktop.230313mzl4w4u92"
    ]

    private let browserBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser",
        "org.chromium.Chromium"
    ]

    private init() {}

    func extractCurrentAppMetadata() -> AppMetadata {
        let workspace = NSWorkspace.shared

        guard let frontmostApp = workspace.frontmostApplication else {
            return AppMetadata(
                appName: "Unknown",
                bundleIdentifier: nil,
                windowTitle: nil
            )
        }

        let appName = frontmostApp.localizedName ?? "Unknown"
        let bundleIdentifier = frontmostApp.bundleIdentifier
        let windowTitle = extractWindowTitle(for: frontmostApp)

        return AppMetadata(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle
        )
    }

    func extractExtendedMetadata() -> ExtendedAppMetadata {
        let workspace = NSWorkspace.shared

        guard let frontmostApp = workspace.frontmostApplication else {
            return ExtendedAppMetadata(
                appName: "Unknown",
                bundleIdentifier: nil,
                windowTitle: nil,
                activityContext: ActivityContext.current()
            )
        }

        let appName = frontmostApp.localizedName ?? "Unknown"
        let bundleIdentifier = frontmostApp.bundleIdentifier
        let windowTitle = extractWindowTitle(for: frontmostApp)

        var context = ActivityContext.current()

        if let bundleId = bundleIdentifier {
            if isCodeEditor(bundleId: bundleId) {
                if let projectPath = extractProjectPath(from: windowTitle, bundleId: bundleId) {
                    context.projectPath = projectPath
                    context.gitBranch = extractGitBranch(from: projectPath)
                }
            }

            if isBrowser(bundleId: bundleId) {
                let browserInfo = extractBrowserInfo(for: frontmostApp)
                context.browserTabUrl = browserInfo.url
                context.browserTabTitle = browserInfo.title ?? windowTitle
            }
        }

        context.activitySessionId = ActivitySessionManager.shared.getOrCreateSession(for: appName)

        return ExtendedAppMetadata(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            activityContext: context
        )
    }

    private func extractWindowTitle(for app: NSRunningApplication) -> String? {
        guard let pid = app.processIdentifier as pid_t? else {
            return nil
        }

        let appRef = AXUIElementCreateApplication(pid)
        var windowValue: AnyObject?

        let result = AXUIElementCopyAttributeValue(
            appRef,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        )

        guard result == .success,
              let window = windowValue else {
            return nil
        }

        var titleValue: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        if titleResult == .success,
           let title = titleValue as? String,
           !title.isEmpty {
            return title
        }

        return nil
    }

    private func isCodeEditor(bundleId: String) -> Bool {
        codeEditorBundleIds.contains(bundleId)
    }

    private func isBrowser(bundleId: String) -> Bool {
        browserBundleIds.contains(bundleId)
    }

    private func extractProjectPath(from windowTitle: String?, bundleId: String) -> String? {
        guard let title = windowTitle else { return nil }

        switch bundleId {
        case "com.apple.dt.Xcode":
            if let dashIndex = title.firstIndex(of: "—") {
                let projectPart = title[..<dashIndex].trimmingCharacters(in: .whitespaces)
                return findProjectDirectory(named: projectPart)
            }
            return nil

        case "com.microsoft.VSCode":
            if let dashIndex = title.lastIndex(of: "-") {
                var projectPart = title[title.index(after: dashIndex)...]
                    .trimmingCharacters(in: .whitespaces)
                if projectPart.hasSuffix(" - Visual Studio Code") {
                    projectPart = String(projectPart.dropLast(" - Visual Studio Code".count))
                }
                if projectPart.hasPrefix("/") {
                    return projectPart
                }
                return findProjectDirectory(named: projectPart)
            }
            return nil

        default:
            let patterns = [
                " — ", " - ", " – "
            ]
            for pattern in patterns {
                if let range = title.range(of: pattern) {
                    let projectPart = title[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                    if let path = findProjectDirectory(named: projectPart) {
                        return path
                    }
                }
            }
            return nil
        }
    }

    private func findProjectDirectory(named name: String) -> String? {
        let commonPaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Projects"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("repos"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("workspace")
        ]

        for basePath in commonPaths {
            let projectPath = basePath.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: projectPath.path) {
                return projectPath.path
            }
        }

        return nil
    }

    private func extractGitBranch(from projectPath: String?) -> String? {
        guard let path = projectPath else { return nil }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !branch.isEmpty {
                    return branch
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    private func extractBrowserInfo(for app: NSRunningApplication) -> (url: String?, title: String?) {
        guard let pid = app.processIdentifier as pid_t?,
              let bundleId = app.bundleIdentifier else {
            return (nil, nil)
        }

        let appRef = AXUIElementCreateApplication(pid)

        var windowValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let window = windowValue else {
            return (nil, nil)
        }

        var titleValue: AnyObject?
        _ = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleValue)
        let title = titleValue as? String

        var url: String? = nil

        switch bundleId {
        case "com.apple.Safari":
            url = extractSafariURL(from: window as! AXUIElement)

        case "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac":
            url = extractChromiumURL(from: window as! AXUIElement)

        case "org.mozilla.firefox":
            url = extractFirefoxURL(from: window as! AXUIElement)

        default:
            url = extractGenericBrowserURL(from: window as! AXUIElement)
        }

        return (url, title)
    }

    private func extractSafariURL(from window: AXUIElement) -> String? {
        return findURLTextField(in: window)
    }

    private func extractChromiumURL(from window: AXUIElement) -> String? {
        return findURLTextField(in: window)
    }

    private func extractFirefoxURL(from window: AXUIElement) -> String? {
        return findURLTextField(in: window)
    }

    private func extractGenericBrowserURL(from window: AXUIElement) -> String? {
        return findURLTextField(in: window)
    }

    private func findURLTextField(in element: AXUIElement) -> String? {
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let childArray = children as? [AXUIElement] else {
            return nil
        }

        for child in childArray {
            var role: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)

            if let roleStr = role as? String {
                if roleStr == "AXTextField" || roleStr == "AXComboBox" {
                    var description: AnyObject?
                    AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &description)

                    if let desc = description as? String,
                       desc.lowercased().contains("url") || desc.lowercased().contains("address") {
                        var value: AnyObject?
                        if AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &value) == .success,
                           let urlString = value as? String,
                           !urlString.isEmpty {
                            return urlString
                        }
                    }
                }

                if roleStr == "AXGroup" || roleStr == "AXToolbar" || roleStr == "AXSplitGroup" {
                    if let found = findURLTextField(in: child) {
                        return found
                    }
                }
            }
        }

        return nil
    }

    func checkAccessibilityPermissions() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
