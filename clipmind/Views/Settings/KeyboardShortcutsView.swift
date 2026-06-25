//
//  KeyboardShortcutsView.swift
//  clipmind
//
//  Keyboard shortcuts help panel
//

import SwiftUI

/// Keyboard shortcuts help view
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text("Master ClipMind with these shortcuts")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.lg)

            Divider()

            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    // Global shortcuts
                    ShortcutSection(title: "Global", icon: "globe") {
                        ShortcutRow(keys: ["⌘", "⇧", "V"], description: "Open floating search panel")
                    }

                    // Floating search shortcuts
                    ShortcutSection(title: "Floating Search", icon: "magnifyingglass") {
                        ShortcutRow(keys: ["↑", "↓"], description: "Navigate items")
                        ShortcutRow(keys: ["↵"], description: "Select item")
                        ShortcutRow(keys: ["⎋"], description: "Close panel")
                        ShortcutRow(keys: ["⌘", "1-9"], description: "Quick select (items 1-9)")
                    }

                    // Main window shortcuts
                    ShortcutSection(title: "Main Window", icon: "rectangle.expand.vertical") {
                        ShortcutRow(keys: ["⌘", "F"], description: "Focus search")
                        ShortcutRow(keys: ["⌘", "W"], description: "Close window")
                        ShortcutRow(keys: ["⌘", "Click"], description: "Multi-select items")
                        ShortcutRow(keys: ["⌫"], description: "Delete selected item")
                    }

                    // Workspace shortcuts
                    ShortcutSection(title: "Workspaces", icon: "square.stack.3d.up") {
                        ShortcutRow(keys: ["⌘", "N"], description: "New workspace")
                        ShortcutRow(keys: ["⌘", "E"], description: "Edit workspace")
                        ShortcutRow(keys: ["⌘", "1-5"], description: "Switch workspace")
                    }

                    // Settings shortcuts
                    ShortcutSection(title: "Settings", icon: "gear") {
                        ShortcutRow(keys: ["⌘", ","], description: "Open preferences")
                        ShortcutRow(keys: ["⌘", "?"], description: "Show help")
                    }
                }
                .padding(DesignTokens.Spacing.xl)
            }

            Divider()

            // Footer
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.Colors.accentPrimary)

                Text("Tip: Hold ⌘ to see available shortcuts in any view")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .frame(width: 500, height: 600)
        .background(
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
        )
    }
}

// MARK: - Shortcut Section

private struct ShortcutSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.accentPrimary)

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }

            GlassCard(padding: DesignTokens.Spacing.md, intensity: .subtle) {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    content
                }
            }
        }
    }
}

// MARK: - Shortcut Row

private struct ShortcutRow: View {
    let keys: [String]
    let description: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
                        )
                }
            }

            Text(description)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    KeyboardShortcutsView()
}
