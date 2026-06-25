//
//  Typography.swift
//  clipmind
//
//  Unified text components with consistent styling
//

import SwiftUI

// MARK: - Text Styles

extension Text {
    func displayLarge() -> some View {
        self.font(.system(size: 32, weight: .bold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    func displayMedium() -> some View {
        self.font(.system(size: 24, weight: .bold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    func displaySmall() -> some View {
        self.font(.system(size: 20, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    func headlineLarge() -> some View {
        self.font(.system(size: 18, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    func headlineMedium() -> some View {
        self.font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    func headlineSmall() -> some View {
        self.font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    func bodyLarge() -> some View {
        self.font(.system(size: 15, weight: .regular))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
    }

    func bodyMedium() -> some View {
        self.font(.system(size: 13, weight: .regular))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
    }

    func bodySmall() -> some View {
        self.font(.system(size: 12, weight: .regular))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
    }

    func labelLarge() -> some View {
        self.font(.system(size: 13, weight: .medium))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    func labelMedium() -> some View {
        self.font(.system(size: 12, weight: .medium))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
    }

    func labelSmall() -> some View {
        self.font(.system(size: 11, weight: .medium))
            .foregroundStyle(DesignTokens.Colors.textTertiary)
    }

    func caption() -> some View {
        self.font(.system(size: 10, weight: .regular))
            .foregroundStyle(DesignTokens.Colors.textTertiary)
    }

    func overline() -> some View {
        self.font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textTertiary)
            .textCase(.uppercase)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionLabel: String?

    var body: some View {
        HStack {
            Text(title)
                .overline()

            Spacer()

            if let action = action, let actionLabel = actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .caption()
                        .foregroundStyle(DesignTokens.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview("Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Display")

                Text("Display Large")
                    .displayLarge()

                Text("Display Medium")
                    .displayMedium()

                Text("Display Small")
                    .displaySmall()
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Headlines")

                Text("Headline Large")
                    .headlineLarge()

                Text("Headline Medium")
                    .headlineMedium()

                Text("Headline Small")
                    .headlineSmall()
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Body")

                Text("Body Large - The quick brown fox jumps over the lazy dog")
                    .bodyLarge()

                Text("Body Medium - The quick brown fox jumps over the lazy dog")
                    .bodyMedium()

                Text("Body Small - The quick brown fox jumps over the lazy dog")
                    .bodySmall()
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Labels")

                Text("Label Large")
                    .labelLarge()

                Text("Label Medium")
                    .labelMedium()

                Text("Label Small")
                    .labelSmall()

                Text("Caption")
                    .caption()

                Text("Overline")
                    .overline()
            }
        }
        .padding(40)
    }
    .frame(width: 600, height: 800)
}
