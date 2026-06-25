//
//  WorkspaceEditorView.swift
//  clipmind
//
//  Editor for creating and editing workspaces
//

import SwiftUI

/// Editor view for creating or editing a workspace
struct WorkspaceEditorView: View {
    @State private var editedWorkspace: Workspace
    let workspaceService: WorkspaceService
    let onSave: (Workspace) -> Void
    let onCancel: () -> Void

    @State private var newBundleId = ""
    @State private var showingColorPicker = false

    init(
        workspace: Workspace,
        workspaceService: WorkspaceService,
        onSave: @escaping (Workspace) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _editedWorkspace = State(initialValue: workspace)
        self.workspaceService = workspaceService
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    // Basic info
                    basicInfoSection

                    // Color picker
                    colorSection

                    // App filters
                    appFilterSection

                    // Project path
                    projectPathSection
                }
                .padding(DesignTokens.Spacing.xl)
            }

            Divider()

            // Footer buttons
            footer
        }
        .frame(width: 600, height: 700)
        .background(
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Circle()
                .fill(editedWorkspace.swiftUIColor)
                .frame(width: 32, height: 32)
                .shadow(color: editedWorkspace.swiftUIColor.opacity(0.3), radius: 8, x: 0, y: 4)

            Text(editedWorkspace.name.isEmpty ? "New Workspace" : editedWorkspace.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Basic Information")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .textCase(.uppercase)

            GlassCard(padding: DesignTokens.Spacing.md, intensity: .subtle) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Name")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)

                        TextField("Workspace name", text: $editedWorkspace.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs, style: .continuous)
                                    .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.3))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Color Section

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Color")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .textCase(.uppercase)

            GlassCard(padding: DesignTokens.Spacing.md, intensity: .subtle) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.sm), count: 8), spacing: DesignTokens.Spacing.sm) {
                    ForEach(WorkspaceService.colorPalette, id: \.self) { colorHex in
                        ColorPickerButton(
                            color: colorHex,
                            isSelected: editedWorkspace.color == colorHex
                        ) {
                            withAnimation(DesignTokens.Animation.spring) {
                                editedWorkspace.color = colorHex
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - App Filter Section

    private var appFilterSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Auto-assign from Apps")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .textCase(.uppercase)

            GlassCard(padding: DesignTokens.Spacing.md, intensity: .subtle) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Clipboard items from these apps will be automatically assigned to this workspace")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    // Add new bundle ID
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        TextField("com.example.app", text: $newBundleId)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs, style: .continuous)
                                    .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.3))
                            )

                        Button(action: addBundleId) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(DesignTokens.Colors.accentPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(newBundleId.isEmpty)
                    }

                    // List of bundle IDs
                    if !editedWorkspace.appFilter.isEmpty {
                        Divider()
                            .padding(.vertical, DesignTokens.Spacing.xs)

                        VStack(spacing: DesignTokens.Spacing.xs) {
                            ForEach(editedWorkspace.appFilter, id: \.self) { bundleId in
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(editedWorkspace.swiftUIColor)

                                    Text(bundleId)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                                    Spacer()

                                    Button(action: { removeBundleId(bundleId) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs, style: .continuous)
                                        .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.2))
                                )
                            }
                        }
                    }

                    // Common apps suggestion
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Common Apps:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)

                        FlowLayout(spacing: DesignTokens.Spacing.xs) {
                            ForEach(commonBundleIds, id: \.self) { bundleId in
                                Button(action: { quickAddBundleId(bundleId) }) {
                                    Text(bundleId.components(separatedBy: ".").last ?? bundleId)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                        .padding(.horizontal, DesignTokens.Spacing.xs)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.xs)
                }
            }
        }
    }

    // MARK: - Project Path Section

    private var projectPathSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Project Path (Optional)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .textCase(.uppercase)

            GlassCard(padding: DesignTokens.Spacing.md, intensity: .subtle) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Clipboard items with window titles containing this path will be auto-assigned")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    TextField("/Users/username/Projects/MyProject", text: Binding(
                        get: { editedWorkspace.projectPath ?? "" },
                        set: { editedWorkspace.projectPath = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs, style: .continuous)
                            .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.3))
                    )
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            SecondaryButton("Cancel", action: onCancel)

            Spacer()

            PrimaryButton(
                "Save Workspace",
                isDisabled: editedWorkspace.name.isEmpty,
                action: { onSave(editedWorkspace) }
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // MARK: - Actions

    private func addBundleId() {
        guard !newBundleId.isEmpty else { return }

        withAnimation(DesignTokens.Animation.spring) {
            if !editedWorkspace.appFilter.contains(newBundleId) {
                editedWorkspace.appFilter.append(newBundleId)
            }
            newBundleId = ""
        }
    }

    private func removeBundleId(_ bundleId: String) {
        withAnimation(DesignTokens.Animation.spring) {
            editedWorkspace.appFilter.removeAll { $0 == bundleId }
        }
    }

    private func quickAddBundleId(_ bundleId: String) {
        guard !editedWorkspace.appFilter.contains(bundleId) else { return }

        withAnimation(DesignTokens.Animation.spring) {
            editedWorkspace.appFilter.append(bundleId)
        }
    }

    // MARK: - Common Bundle IDs

    private var commonBundleIds: [String] {
        [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.google.Chrome",
            "com.figma.Desktop",
            "com.adobe.Photoshop",
            "com.apple.Notes",
            "com.notion.desktop",
            "com.tinyspeck.slackmacgap"
        ]
    }
}

// MARK: - Color Picker Button

private struct ColorPickerButton: View {
    let color: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: color) ?? .blue)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: (Color(hex: color) ?? .blue).opacity(0.3), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
                .scaleEffect(isSelected ? 1.1 : (isHovered ? 1.05 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Flow Layout
// Note: FlowLayout is now defined in Views/Shared/FlowLayout.swift and available globally

// MARK: - Preview

#Preview("Workspace Editor") {
    WorkspaceEditorView(
        workspace: Workspace.sampleDevelopment,
        workspaceService: WorkspaceService(),
        onSave: { _ in },
        onCancel: {}
    )
}
