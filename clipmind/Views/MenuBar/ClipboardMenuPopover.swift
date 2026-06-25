//
//  ClipboardMenuPopover.swift
//  clipmind
//
//  Glassy popover showing 5 most recent clipboard items
//

import SwiftUI

/// Popover view showing recent clipboard items with glassy design
struct ClipboardMenuPopover: View {
    @EnvironmentObject var clipboardStore: ClipboardStore
    @State private var carouselIndex = 0

    let onOpenMainWindow: () -> Void
    let onQuit: () -> Void
    var onClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Header with more breathing room
            header
                .padding(.bottom, DesignTokens.Spacing.xs)

            Divider()
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            DesignTokens.Colors.borderSubtle,
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            // Recent items list with better spacing
            if clipboardStore.recentItems.isEmpty {
                emptyState
            } else {
                itemsList
            }

            Divider()
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            DesignTokens.Colors.borderSubtle,
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            // Footer actions with refined design
            footer
                .padding(.top, DesignTokens.Spacing.xs)
        }
        .frame(width: DesignTokens.Sizes.menuPopoverWidth)
        .background(
            ZStack {
                // Enhanced glass background
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)

                // Subtle gradient overlay for depth
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.03),
                        Color.clear,
                        Color.black.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            AppLogo(size: .small, showShadow: false)

            VStack(alignment: .leading, spacing: 2) {
                Text("ClipMind")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("\(clipboardStore.items.count) items in history")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            // Refined icon button
            Button(action: onOpenMainWindow) {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.3))
                    )
            }
            .buttonStyle(.plain)
            .help("Open Main Window")
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - Items List

    private var itemsList: some View {
        CardCarousel(
            items: clipboardStore.recentItems,
            currentIndex: $carouselIndex,
            onActivate: { item in handleItemTap(item) },
            onDelete: { item in clipboardStore.deleteItem(item) }
        )
        .onChange(of: clipboardStore.recentItems.count) { _ in
            carouselIndex = 0
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.accentPrimary.opacity(0.1),
                                DesignTokens.Colors.accentPrimary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.textSecondary,
                                DesignTokens.Colors.textTertiary
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("No Clipboard History")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("Copy something to get started")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // View All button
            Button(action: onOpenMainWindow) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Dashboard")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                        .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.3))
                )
            }
            .buttonStyle(.plain)

            // Quit button
            Button(action: onQuit) {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.error)
                    .frame(width: 40)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                            .fill(DesignTokens.Colors.error.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    // MARK: - Actions

    private func handleItemTap(_ item: ClipboardItem) {
        clipboardStore.copyItemToClipboard(item)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        onClose()
    }
}

#Preview("Clipboard Menu Popover") {
    ClipboardMenuPopover(
        onOpenMainWindow: { print("Open main window") },
        onQuit: { print("Quit") }
    )
    .environmentObject(ClipboardStore())
    .frame(height: 500)
}

#Preview("Empty State") {
    ClipboardMenuPopover(
        onOpenMainWindow: { print("Open main window") },
        onQuit: { print("Quit") }
    )
    .environmentObject({
        let store = ClipboardStore()
        store.clearAll()
        return store
    }())
    .frame(height: 300)
}
