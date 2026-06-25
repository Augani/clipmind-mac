//
//  Tokens.swift
//  clipmind
//
//  Design system tokens for ClipMind
//  macOS Ventura/Sonoma glassy aesthetic with adaptive dark/light modes
//

import SwiftUI

/// Design system tokens for ClipMind
/// Provides colors, typography, spacing, and other design values
struct DesignTokens {

    // MARK: - Colors

    struct Colors {
        // MARK: Glass Materials
        static let glassPrimary = Color(nsColor: .controlBackgroundColor).opacity(0.7)
        static let glassSecondary = Color(nsColor: .windowBackgroundColor).opacity(0.5)
        static let glassHover = Color(nsColor: .controlBackgroundColor).opacity(0.9)

        // MARK: Surfaces
        static let surfacePrimary = Color(nsColor: .windowBackgroundColor)
        static let surfaceSecondary = Color(nsColor: .controlBackgroundColor)
        static let surfaceTertiary = Color(nsColor: .underPageBackgroundColor)

        // MARK: Content
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color(nsColor: .tertiaryLabelColor)

        // MARK: Accent & Interactive
        static let accentPrimary = Color.accentColor
        static let accentSecondary = Color.accentColor.opacity(0.6)

        // MARK: Semantic Colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        // MARK: Content Type Badge Colors
        static let badgeText = Color.blue
        static let badgeImage = Color.purple
        static let badgeCode = Color.green
        static let badgeURL = Color.orange
        static let badgeFile = Color.gray

        // MARK: Overlays
        static let overlayLight = Color.black.opacity(0.05)
        static let overlayMedium = Color.black.opacity(0.1)
        static let overlayDark = Color.black.opacity(0.2)

        // MARK: Borders
        static let borderSubtle = Color(nsColor: .separatorColor)
        static let borderMedium = Color(nsColor: .separatorColor).opacity(0.5)
        static let borderStrong = Color(nsColor: .separatorColor).opacity(0.8)
    }

    // MARK: - Typography

    struct Typography {
        // MARK: Font Sizes
        static let largeTitle: CGFloat = 28
        static let title1: CGFloat = 22
        static let title2: CGFloat = 17
        static let title3: CGFloat = 15
        static let headline: CGFloat = 13
        static let body: CGFloat = 13
        static let callout: CGFloat = 12
        static let subheadline: CGFloat = 11
        static let footnote: CGFloat = 10
        static let caption1: CGFloat = 10
        static let caption2: CGFloat = 9

        // MARK: Font Weights
        static let weightRegular: Font.Weight = .regular
        static let weightMedium: Font.Weight = .medium
        static let weightSemibold: Font.Weight = .semibold
        static let weightBold: Font.Weight = .bold

        // MARK: Predefined Styles
        static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
            .system(size: largeTitle, weight: weight)
        }

        static func title1(_ weight: Font.Weight = .semibold) -> Font {
            .system(size: title1, weight: weight)
        }

        static func title2(_ weight: Font.Weight = .semibold) -> Font {
            .system(size: title2, weight: weight)
        }

        static func title3(_ weight: Font.Weight = .medium) -> Font {
            .system(size: title3, weight: weight)
        }

        static func headline(_ weight: Font.Weight = .semibold) -> Font {
            .system(size: headline, weight: weight)
        }

        static func body(_ weight: Font.Weight = .regular) -> Font {
            .system(size: body, weight: weight)
        }

        static func callout(_ weight: Font.Weight = .regular) -> Font {
            .system(size: callout, weight: weight)
        }

        static func subheadline(_ weight: Font.Weight = .regular) -> Font {
            .system(size: subheadline, weight: weight)
        }

        static func footnote(_ weight: Font.Weight = .regular) -> Font {
            .system(size: footnote, weight: weight)
        }

        static func caption(_ weight: Font.Weight = .regular) -> Font {
            .system(size: caption1, weight: weight)
        }
    }

    // MARK: - Spacing

    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
        static let round: CGFloat = 999
    }

    // MARK: - Shadows

    struct Shadows {
        static let sm: CGFloat = 2
        static let md: CGFloat = 4
        static let lg: CGFloat = 8
        static let xl: CGFloat = 16

        static let subtle = Shadow(color: .black.opacity(0.05), radius: sm, x: 0, y: 1)
        static let medium = Shadow(color: .black.opacity(0.1), radius: md, x: 0, y: 2)
        static let strong = Shadow(color: .black.opacity(0.15), radius: lg, x: 0, y: 4)
        static let dramatic = Shadow(color: .black.opacity(0.2), radius: xl, x: 0, y: 8)
    }

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Blur

    struct Blur {
        static let subtle: CGFloat = 10
        static let medium: CGFloat = 20
        static let strong: CGFloat = 30
        static let dramatic: CGFloat = 50
    }

    // MARK: - Animation

    struct Animation {
        static let quick: SwiftUI.Animation = .easeInOut(duration: 0.15)
        static let smooth: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let gentle: SwiftUI.Animation = .easeInOut(duration: 0.35)
        static let spring: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.7)
        static let bouncy: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.6)
    }

    // MARK: - Sizes

    struct Sizes {
        // Menu bar popover
        static let menuPopoverWidth: CGFloat = 360
        static let menuItemHeight: CGFloat = 72

        // Icons
        static let iconXS: CGFloat = 12
        static let iconSM: CGFloat = 16
        static let iconMD: CGFloat = 20
        static let iconLG: CGFloat = 24
        static let iconXL: CGFloat = 32

        // App icons
        static let appIconSM: CGFloat = 20
        static let appIconMD: CGFloat = 24
        static let appIconLG: CGFloat = 32

        // Badges
        static let badgeHeight: CGFloat = 18
        static let badgePadding: CGFloat = 6
    }
}
