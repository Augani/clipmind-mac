//
//  TimelineItemRow.swift
//  clipmind
//
//  Lean single-line row for the timeline dashboard
//

import SwiftUI

struct TimelineItemRow: View {
    let item: ClipboardItem
    let onTap: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.md) {
                typeGlyph

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.truncatedPreview(maxLength: 120))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    metadataRow
                }

                Spacer(minLength: 0)

                if isHovered {
                    HStack(spacing: 4) {
                        rowAction("doc.on.doc", action: onCopy)
                        rowAction("trash", action: onDelete, destructive: true)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                    .fill(isHovered ? DesignTokens.Colors.surfaceSecondary.opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if reduceMotion {
                isHovered = hovering
            } else {
                withAnimation(DesignTokens.Animation.quick) { isHovered = hovering }
            }
        }
        .contextMenu {
            Button(action: onCopy) { Label("Copy to Clipboard", systemImage: "doc.on.doc") }
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }

    private var typeGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(item.type.color.opacity(0.16))
                .frame(width: 30, height: 30)
            Image(systemName: item.type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(item.type.color)
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 6) {
            if item.origin == .universalClipboard {
                HStack(spacing: 2) {
                    Image(systemName: "iphone").font(.system(size: 8, weight: .medium))
                    Text("iPhone").font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(DesignTokens.Colors.accentSecondary)
            }

            Text(item.sourceApp)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .lineLimit(1)

            TimestampLabel(item.timestamp)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(DesignTokens.Colors.textTertiary.opacity(0.8))
        }
    }

    private func rowAction(_ icon: String, action: @escaping () -> Void, destructive: Bool = false) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(destructive ? DesignTokens.Colors.error : DesignTokens.Colors.textSecondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(DesignTokens.Colors.surfaceSecondary.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destructive ? "Delete" : "Copy")
    }
}
