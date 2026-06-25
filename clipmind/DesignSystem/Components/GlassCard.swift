//
//  GlassCard.swift
//  clipmind
//
//  Glassy card component with blur and vibrancy effects
//  macOS Ventura/Sonoma native aesthetic
//

import SwiftUI

/// A glass-effect card with blur, vibrancy, and optional hover states
struct GlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let hasBorder: Bool
    let hasHoverEffect: Bool
    let intensity: GlassIntensity

    @State private var isHovered = false

    enum GlassIntensity {
        case subtle
        case medium
        case strong

        var opacity: CGFloat {
            switch self {
            case .subtle: return 0.6
            case .medium: return 0.75
            case .strong: return 0.9
            }
        }

        var hoverOpacity: CGFloat {
            switch self {
            case .subtle: return 0.7
            case .medium: return 0.85
            case .strong: return 0.95
            }
        }
    }

    init(
        padding: CGFloat = DesignTokens.Spacing.lg,
        cornerRadius: CGFloat = DesignTokens.CornerRadius.lg,
        hasBorder: Bool = true,
        hasHoverEffect: Bool = false,
        intensity: GlassIntensity = .medium,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.hasBorder = hasBorder
        self.hasHoverEffect = hasHoverEffect
        self.intensity = intensity
    }

    var body: some View {
        content
            .padding(padding)
            .background(glassBackground)
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: isHovered && hasHoverEffect ? .black.opacity(0.12) : .black.opacity(0.04),
                radius: isHovered && hasHoverEffect ? 12 : 6,
                x: 0,
                y: isHovered && hasHoverEffect ? 6 : 3
            )
            .shadow(
                color: isHovered && hasHoverEffect ? .black.opacity(0.08) : .black.opacity(0.02),
                radius: isHovered && hasHoverEffect ? 24 : 12,
                x: 0,
                y: isHovered && hasHoverEffect ? 12 : 6
            )
            .scaleEffect(isHovered && hasHoverEffect ? 1.015 : 1.0)
            .animation(DesignTokens.Animation.spring, value: isHovered)
            .onHover { hovering in
                if hasHoverEffect {
                    isHovered = hovering
                }
            }
    }

    private var glassBackground: some View {
        ZStack {
            // Base glass material with enhanced blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(isHovered && hasHoverEffect ? intensity.hoverOpacity : intensity.opacity)

            // Multi-layered gradient for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(isHovered && hasHoverEffect ? 0.12 : 0.08),
                    Color.white.opacity(isHovered && hasHoverEffect ? 0.04 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle shimmer overlay
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.white.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderOverlay: some View {
        Group {
            if hasBorder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered && hasHoverEffect ? 0.3 : 0.2),
                                Color.white.opacity(isHovered && hasHoverEffect ? 0.15 : 0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered && hasHoverEffect ? 1.0 : 0.75
                    )
            }
        }
    }
}

/// Native NSVisualEffectView wrapper for true macOS glass effects
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply glass card styling to any view
    func glassCard(
        padding: CGFloat = DesignTokens.Spacing.lg,
        cornerRadius: CGFloat = DesignTokens.CornerRadius.lg,
        hasBorder: Bool = true,
        hasHoverEffect: Bool = false,
        intensity: GlassCard<Self>.GlassIntensity = .medium
    ) -> some View {
        GlassCard(
            padding: padding,
            cornerRadius: cornerRadius,
            hasBorder: hasBorder,
            hasHoverEffect: hasHoverEffect,
            intensity: intensity
        ) {
            self
        }
    }

    /// Apply glass background material
    func glassMaterial(_ material: NSVisualEffectView.Material = .hudWindow) -> some View {
        self.background(
            VisualEffectBlur(material: material, blendingMode: .behindWindow)
        )
    }
}

// MARK: - Preview

#Preview("Glass Card Variants") {
    VStack(spacing: 24) {
        // Basic glass card
        GlassCard(intensity: .subtle) {
            Text("Subtle Glass Card")
                .font(DesignTokens.Typography.body())
        }

        // Glass card with hover effect
        GlassCard(hasHoverEffect: true, intensity: .medium) {
            Text("Hover over me!")
                .font(DesignTokens.Typography.body())
        }

        // Strong intensity card
        GlassCard(hasHoverEffect: true, intensity: .strong) {
            Text("Strong Glass Effect")
                .font(DesignTokens.Typography.body())
        }

        // Custom padding and corner radius
        GlassCard(
            padding: DesignTokens.Spacing.xl,
            cornerRadius: DesignTokens.CornerRadius.xl,
            hasHoverEffect: true
        ) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Premium Glass Card")
                    .font(DesignTokens.Typography.headline(.semibold))
                Text("With enhanced visual hierarchy")
                    .font(DesignTokens.Typography.caption())
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
    }
    .frame(width: 320)
    .padding(40)
}
