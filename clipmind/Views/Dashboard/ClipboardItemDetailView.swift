//
//  ClipboardItemDetailView.swift
//  clipmind
//
//  Detail view for viewing clipboard item information
//

import SwiftUI

/// Detail modal showing full clipboard item information
struct ClipboardItemDetailView: View {
    let item: ClipboardItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var clipboardStore: ClipboardStore
    @State private var fullItem: ClipboardItem?

    private var displayItem: ClipboardItem {
        fullItem ?? item
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    previewSection

                    metadataSection

                    if let workspaceId = displayItem.workspaceId,
                       let workspace = clipboardStore.workspaceService.workspace(withId: workspaceId) {
                        workspaceSection(workspace)
                    }

                    actionsSection
                }
                .padding(DesignTokens.Spacing.xl)
            }

            Divider()

            footer
        }
        .frame(width: 700, height: 800)
        .background(
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
        )
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let loaded = clipboardStore.loadFullItem(id: item.id)
                DispatchQueue.main.async {
                    fullItem = loaded
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: displayItem.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(DesignTokens.Colors.accentPrimary)

            Text("Clipboard Item Details")
                .headlineLarge()

            Spacer()

            IconButton(icon: "xmark.circle.fill", action: { dismiss() }, size: .medium, variant: .ghost)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Content")
                .headlineSmall()

            GlassCard(padding: DesignTokens.Spacing.md, intensity: .medium) {
                switch displayItem.content {
                case .text(let text):
                    Text(text)
                        .bodyMedium()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                case .url(let url):
                    VStack(alignment: .leading, spacing: 8) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "link")
                                Text(url.absoluteString)
                                    .bodyMedium()
                                    .lineLimit(1)
                                Image(systemName: "arrow.up.forward.square")
                            }
                        }

                        Text(url.absoluteString)
                            .labelSmall()
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                case .image(let data):
                    if let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                    } else {
                        Text("Unable to display image")
                            .labelMedium()
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }

                case .file(let url):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc")
                            Text(url.lastPathComponent)
                                .bodyMedium()
                        }

                        Text(url.path)
                            .labelSmall()
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Metadata")
                .headlineSmall()

            GlassCard(padding: DesignTokens.Spacing.md, intensity: .subtle) {
                VStack(alignment: .leading, spacing: 12) {
                    MetadataRow(label: "Type", value: displayItem.type.rawValue.capitalized)
                    MetadataRow(label: "Source App", value: displayItem.sourceApp)

                    if let windowTitle = displayItem.windowTitle {
                        MetadataRow(label: "Window", value: windowTitle)
                    }

                    MetadataRow(label: "Bundle ID", value: displayItem.sourceBundleIdentifier ?? "Unknown")
                    MetadataRow(label: "Timestamp", value: formatDate(displayItem.timestamp))

                    if displayItem.isMarkedSensitive {
                        HStack {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(DesignTokens.Colors.error)
                            Text("Sensitive Content Detected")
                                .labelMedium()
                                .foregroundStyle(DesignTokens.Colors.error)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Workspace Section

    private func workspaceSection(_ workspace: Workspace) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Workspace")
                .headlineSmall()

            GlassCard(padding: DesignTokens.Spacing.md, intensity: .subtle) {
                HStack {
                    Circle()
                        .fill(Color(hex: workspace.color) ?? .gray)
                        .frame(width: 12, height: 12)

                    Text(workspace.name)
                        .bodyMedium()

                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Actions")
                .headlineSmall()

            HStack(spacing: DesignTokens.Spacing.md) {
                SecondaryButton("Copy to Clipboard", icon: "doc.on.doc") {
                    clipboardStore.copyItemToClipboard(displayItem)
                    ToastManager.shared.success("Copied to clipboard")
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            SecondaryButton("Close", action: { dismiss() })

            Spacer()

            PrimaryButton("Copy & Close", icon: "doc.on.doc") {
                clipboardStore.copyItemToClipboard(displayItem)
                ToastManager.shared.success("Copied to clipboard")
                dismiss()
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // MARK: - Helper Functions

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

}

// MARK: - Metadata Row

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .labelMedium()
                .frame(width: 100, alignment: .leading)

            Text(value)
                .bodyMedium()
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ClipboardItemDetailView(
        item: ClipboardItem(
            content: .text("This is a sample clipboard item for preview purposes."),
            type: .text,
            timestamp: Date(),
            sourceApp: "Xcode",
            sourceBundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "Preview.swift"
        )
    )
    .environmentObject(ClipboardStore())
}
