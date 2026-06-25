//
//  Buttons.swift
//  clipmind
//
//  Unified button components with consistent styling
//

import SwiftUI

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var fullWidth: Bool = false

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.fullWidth = fullWidth
    }

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary)
                    .opacity(isDisabled ? 0.5 : 1.0)
            )
            .opacity(isPressed ? 0.8 : 1.0)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var fullWidth: Bool = false

    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isDisabled = isDisabled
        self.fullWidth = fullWidth
    }

    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isHovered
                            ? DesignTokens.Colors.surfaceSecondary.opacity(0.5)
                            : DesignTokens.Colors.surfaceSecondary.opacity(0.3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
                    )
            )
            .opacity(isPressed ? 0.8 : 1.0)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Ghost Button

struct GhostButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false

    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isDisabled = isDisabled
    }

    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(
                isHovered
                    ? DesignTokens.Colors.textPrimary
                    : DesignTokens.Colors.textSecondary
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isHovered
                            ? DesignTokens.Colors.surfaceSecondary.opacity(0.3)
                            : Color.clear
                    )
            )
            .opacity(isPressed ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: ButtonSize = .medium
    var variant: ButtonVariant = .secondary
    var isDisabled: Bool = false

    @State private var isPressed = false
    @State private var isHovered = false

    enum ButtonSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 14
            case .large: return 16
            }
        }

        var frameSize: CGFloat {
            switch self {
            case .small: return 28
            case .medium: return 32
            case .large: return 36
            }
        }
    }

    enum ButtonVariant {
        case primary, secondary, ghost
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(width: size.frameSize, height: size.frameSize)
                .background(background)
                .opacity(isPressed ? 0.6 : 1.0)
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary, .ghost:
            return isHovered ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.Colors.accentPrimary)
        case .secondary:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isHovered
                        ? DesignTokens.Colors.surfaceSecondary.opacity(0.5)
                        : DesignTokens.Colors.surfaceSecondary.opacity(0.3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
                )
        case .ghost:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    isHovered
                        ? DesignTokens.Colors.surfaceSecondary.opacity(0.3)
                        : Color.clear
                )
        }
    }
}

// MARK: - Preview

#Preview("Buttons") {
    VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Primary Buttons")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            HStack(spacing: 12) {
                PrimaryButton("Save", icon: "checkmark") { }
                PrimaryButton("Loading", isLoading: true) { }
                PrimaryButton("Disabled", isDisabled: true) { }
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Secondary Buttons")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            HStack(spacing: 12) {
                SecondaryButton("Cancel", icon: "xmark") { }
                SecondaryButton("Disabled", isDisabled: true) { }
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Ghost Buttons")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            HStack(spacing: 12) {
                GhostButton("Edit", icon: "pencil") { }
                GhostButton("Delete") { }
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Icon Buttons")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            HStack(spacing: 12) {
                IconButton(icon: "plus", action: {}, variant: .primary)
                IconButton(icon: "gear", action: {}, variant: .secondary)
                IconButton(icon: "info.circle", action: {}, variant: .ghost)
            }
        }
    }
    .padding(40)
    .frame(width: 500)
}
