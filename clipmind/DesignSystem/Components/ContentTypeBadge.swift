//
//  ContentTypeBadge.swift
//  clipmind
//
//  Badge component for displaying clipboard content type
//

import SwiftUI

/// Visual badge indicating clipboard content type
struct ContentTypeBadge: View {
    let type: ClipboardItemType
    let size: BadgeSize

    enum BadgeSize {
        case small
        case medium
        case large

        var iconSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 10
            case .large: return 11
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 10
            case .large: return 11
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 3
            case .medium: return 4
            case .large: return 5
            }
        }
    }

    init(type: ClipboardItemType, size: BadgeSize = .medium) {
        self.type = type
        self.size = size
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: size.iconSize, weight: .semibold))

            Text(type.displayName)
                .font(.system(size: size.fontSize, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            ZStack {
                // Subtle glass blur
                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                    .opacity(0.2)

                // Primary color with refined opacity
                type.color
                    .opacity(0.85)

                // Subtle gradient overlay for depth
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.clear,
                        Color.black.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    Color.white.opacity(0.2),
                    lineWidth: 0.5
                )
        )
        .shadow(color: type.color.opacity(0.2), radius: 3, x: 0, y: 1)
        .shadow(color: type.color.opacity(0.1), radius: 6, x: 0, y: 2)
    }
}

#Preview("Content Type Badges") {
    VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medium (Default)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(ClipboardItemType.allCases, id: \.self) { type in
                    ContentTypeBadge(type: type)
                }
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Small")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach(ClipboardItemType.allCases, id: \.self) { type in
                    ContentTypeBadge(type: type, size: .small)
                }
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Large")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ForEach(ClipboardItemType.allCases, id: \.self) { type in
                    ContentTypeBadge(type: type, size: .large)
                }
            }
        }
    }
    .padding(24)
}
