//
//  AppLogo.swift
//  clipmind
//
//  Reusable app logo component
//

import SwiftUI

struct AppLogo: View {
    enum Size {
        case small      // 32pt
        case medium     // 48pt
        case large      // 64pt
        case xlarge     // 96pt
        case hero       // 128pt
        case custom(CGFloat)

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 64
            case .xlarge: return 96
            case .hero: return 128
            case .custom(let size): return size
            }
        }
    }

    let size: Size
    var showShadow: Bool = true

    var body: some View {
        Image("Logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.dimension, height: size.dimension)
            .clipShape(RoundedRectangle(cornerRadius: size.dimension * 0.1875, style: .continuous))
            .shadow(color: showShadow ? .black.opacity(0.1) : .clear, radius: 8, x: 0, y: 4)
    }
}

struct AppLogoWithText: View {
    let logoSize: AppLogo.Size
    var showTagline: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            AppLogo(size: logoSize)

            VStack(spacing: 4) {
                Text("ClipMind")
                    .font(.system(size: textSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if showTagline {
                    Text("Smart Clipboard Manager")
                        .font(.system(size: taglineSize, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var textSize: CGFloat {
        switch logoSize {
        case .small: return 14
        case .medium: return 18
        case .large: return 22
        case .xlarge: return 28
        case .hero: return 32
        case .custom(let size): return size * 0.25
        }
    }

    private var taglineSize: CGFloat {
        textSize * 0.6
    }
}

struct MenuBarIcon: View {
    var isHighlighted: Bool = false

    var body: some View {
        Image("Logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .opacity(isHighlighted ? 1 : 0.9)
    }
}

#Preview("Logo Sizes") {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            AppLogo(size: .small)
            AppLogo(size: .medium)
            AppLogo(size: .large)
        }
        HStack(spacing: 24) {
            AppLogo(size: .xlarge)
            AppLogo(size: .hero)
        }
    }
    .padding(40)
}

#Preview("Logo with Text") {
    VStack(spacing: 32) {
        AppLogoWithText(logoSize: .large)
        AppLogoWithText(logoSize: .xlarge, showTagline: true)
    }
    .padding(40)
}
