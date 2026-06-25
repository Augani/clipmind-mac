//
//  GlassButton.swift
//  clipmind
//
//  Glass-styled button with hover effects
//

import SwiftUI

/// A button with glass styling and smooth hover animations
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: ButtonStyle

    @State private var isHovered = false

    enum ButtonStyle {
        case primary
        case secondary
        case subtle

        var backgroundColor: Color {
            switch self {
            case .primary: return DesignTokens.Colors.accentPrimary.opacity(0.8)
            case .secondary: return DesignTokens.Colors.glassPrimary
            case .subtle: return Color.clear
            }
        }

        var textColor: Color {
            switch self {
            case .primary: return .white
            case .secondary, .subtle: return DesignTokens.Colors.textPrimary
            }
        }
    }

    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: DesignTokens.Typography.caption1, weight: .medium))
                }

                Text(title)
                    .font(DesignTokens.Typography.body(.medium))
            }
            .foregroundStyle(style.textColor)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                ZStack {
                    if style != .subtle {
                        VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                            .opacity(isHovered ? 0.95 : 0.8)
                    }

                    style.backgroundColor
                        .opacity(isHovered ? 1.0 : 0.9)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                    .strokeBorder(
                        style == .subtle ? DesignTokens.Colors.borderSubtle : Color.clear,
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.15 : 0.05),
                radius: isHovered ? 6 : 3,
                x: 0,
                y: isHovered ? 3 : 1
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.spring) {
                isHovered = hovering
            }
        }
    }
}

struct GlassButtonStyle: SwiftUI.ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.body(.medium))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        .opacity(configuration.isPressed ? 0.9 : (isHovered ? 0.95 : 0.8))

                    DesignTokens.Colors.glassPrimary
                        .opacity(configuration.isPressed ? 0.95 : (isHovered ? 1.0 : 0.9))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .shadow(
                color: .black.opacity(isHovered ? 0.15 : 0.05),
                radius: isHovered ? 6 : 3,
                x: 0,
                y: isHovered ? 3 : 1
            )
            .animation(DesignTokens.Animation.spring, value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.spring) {
                    isHovered = hovering
                }
            }
    }
}

#Preview("Glass Buttons") {
    VStack(spacing: 16) {
        GlassButton("Primary Button", icon: "star.fill", style: .primary) {
            print("Primary tapped")
        }

        GlassButton("Secondary Button", icon: "heart", style: .secondary) {
            print("Secondary tapped")
        }

        GlassButton("Subtle Button", style: .subtle) {
            print("Subtle tapped")
        }
    }
    .padding()
    .frame(width: 300)
}
