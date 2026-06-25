//
//  OnboardingView.swift
//  clipmind
//
//  Compact onboarding experience using unified design system
//

import SwiftUI

/// Onboarding flow for new users
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "sparkles",
            title: "Welcome to ClipMind",
            subtitle: "Your intelligent clipboard manager",
            features: [
                "Never lose clipboard content",
                "Smart search with filters",
                "Smart workspaces & organization",
                "100% offline & private"
            ]
        ),
        OnboardingPage(
            icon: "magnifyingglass",
            title: "Smart Search",
            subtitle: "Find anything in your clipboard history",
            features: [
                "Full-text search with scoring",
                "Filter by type, app, or workspace",
                "Fuzzy matching support",
                "100% offline processing"
            ]
        ),
        OnboardingPage(
            icon: "rectangle.3.group",
            title: "Smart Workspaces",
            subtitle: "Auto-organize by project or app",
            features: [
                "Auto-detect source apps",
                "Project path filtering",
                "Custom color coding",
                "Pin important workspaces"
            ]
        ),
        OnboardingPage(
            icon: "command",
            title: "Quick Access",
            subtitle: "Global hotkey from anywhere",
            features: [
                "Default: ⌘⇧V",
                "Customizable shortcuts",
                "Floating search panel",
                "One-click paste"
            ]
        ),
        OnboardingPage(
            icon: "lock.shield",
            title: "Privacy First",
            subtitle: "Your data stays on your Mac",
            features: [
                "Auto-detect sensitive data",
                "End-to-end encryption",
                "Exclude specific apps",
                "Incognito mode available"
            ]
        )
    ]

    var body: some View {
        ZStack {
            // Background
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                Divider()
                    .foregroundStyle(DesignTokens.Colors.borderSubtle)

                // Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index], isWelcomePage: index == 0)
                            .tag(index)
                    }
                }
                .tabViewStyle(.automatic)
                .frame(height: 480)

                Divider()
                    .foregroundStyle(DesignTokens.Colors.borderSubtle)

                // Footer
                footer
            }
        }
        .frame(width: 700, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                AppLogo(size: .small, showShadow: false)

                Text("ClipMind Setup")
                    .headlineMedium()
            }

            Spacer()

            Text("Step \(currentPage + 1) of \(pages.count)")
                .labelSmall()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 16) {
            // Page indicators
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(
                            currentPage == index
                                ? DesignTokens.Colors.accentPrimary
                                : DesignTokens.Colors.borderSubtle
                        )
                        .frame(width: 6, height: 6)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            // Navigation
            HStack(spacing: 12) {
                if currentPage > 0 {
                    SecondaryButton("Back", icon: "chevron.left") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    PrimaryButton("Next", icon: "chevron.right") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                } else {
                    PrimaryButton("Get Started", icon: "checkmark") {
                        completeOnboarding()
                    }
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        withAnimation {
            isPresented = false
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let features: [String]
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    var isWelcomePage: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon or Logo
            if isWelcomePage {
                AppLogo(size: .hero)
            } else {
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.accentPrimary.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)

                    Circle()
                        .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.5))
                        .frame(width: 88, height: 88)
                        .overlay(
                            Circle()
                                .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
                        )

                    Image(systemName: page.icon)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(DesignTokens.Colors.accentPrimary)
                }
            }

            // Title and subtitle
            VStack(spacing: 8) {
                Text(page.title)
                    .displayMedium()
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .bodyLarge()
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 60)

            // Features
            VStack(alignment: .leading, spacing: 10) {
                ForEach(page.features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignTokens.Colors.accentPrimary)

                        Text(feature)
                            .bodyMedium()
                    }
                }
            }
            .padding(.horizontal, 80)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
    }
}

// MARK: - Onboarding Manager

class OnboardingManager {
    static let shared = OnboardingManager()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private init() {}

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}

#Preview("Onboarding View") {
    OnboardingView(isPresented: .constant(true))
}
