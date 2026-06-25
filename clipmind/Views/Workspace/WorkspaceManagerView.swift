//
//  WorkspaceManagerView.swift
//  clipmind
//
//  Workspace management UI with create/edit/delete capabilities
//

import SwiftUI

/// Workspace manager view for organizing clipboard items
struct WorkspaceManagerView: View {
    @ObservedObject var workspaceService: WorkspaceService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var toastManager = ToastManager.shared

    @State private var selectedWorkspace: Workspace?
    @State private var showingEditor = false
    @State private var editingWorkspace: Workspace?
    @State private var workspaceToDelete: Workspace?

    var body: some View {
        NavigationSplitView {
            workspaceList
        } detail: {
            if let workspace = selectedWorkspace {
                workspaceDetail(workspace)
            } else {
                emptySelection
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let workspace = editingWorkspace {
                WorkspaceEditorView(
                    workspace: workspace,
                    workspaceService: workspaceService,
                    onSave: { updatedWorkspace in
                        let isNew = !workspaceService.workspaces.contains(where: { $0.id == updatedWorkspace.id })
                        workspaceService.saveWorkspace(updatedWorkspace)
                        toastManager.success(isNew ? "Workspace created successfully" : "Workspace updated successfully")
                        showingEditor = false
                        selectedWorkspace = updatedWorkspace
                    },
                    onCancel: {
                        showingEditor = false
                    }
                )
            }
        }
        .alert("Delete Workspace", isPresented: .constant(workspaceToDelete != nil), presenting: workspaceToDelete) { workspace in
            Button("Cancel", role: .cancel) {
                workspaceToDelete = nil
            }
            Button("Delete", role: .destructive) {
                confirmDeleteWorkspace(workspace)
            }
        } message: { workspace in
            Text("Are you sure you want to delete '\(workspace.name)'? Items in this workspace will be moved to Uncategorized.")
        }
        .toast()
    }

    // MARK: - Workspace List

    private var workspaceList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Workspaces")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Spacer()

                Button(action: createNewWorkspace) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DesignTokens.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.xl)

            Divider()

            // Workspace list
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(workspaceService.workspaces) { workspace in
                        WorkspaceListItem(
                            workspace: workspace,
                            isSelected: selectedWorkspace?.id == workspace.id,
                            onSelect: {
                                withAnimation(DesignTokens.Animation.spring) {
                                    selectedWorkspace = workspace
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.md)
                .padding(.horizontal, DesignTokens.Spacing.sm)
            }
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
    }

    // MARK: - Workspace Detail

    private func workspaceDetail(_ workspace: Workspace) -> some View {
        VStack(spacing: 0) {
            // Header with color indicator
            HStack(spacing: DesignTokens.Spacing.md) {
                Circle()
                    .fill(workspace.swiftUIColor)
                    .frame(width: 32, height: 32)
                    .shadow(color: workspace.swiftUIColor.opacity(0.3), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text("Created \(workspace.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                Spacer()

                // Action buttons
                HStack(spacing: DesignTokens.Spacing.sm) {
                    GhostButton("Edit", icon: "pencil") {
                        editWorkspace(workspace)
                    }

                    if workspace.id != Workspace.uncategorized.id {
                        Button(action: { workspaceToDelete = workspace }) {
                            Label("Delete", systemImage: "trash")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.xl)

            Divider()

            // Details
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    // App filters
                    if !workspace.appFilter.isEmpty {
                        DetailSection(title: "Auto-assign from Apps") {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                ForEach(workspace.appFilter, id: \.self) { bundleId in
                                    HStack(spacing: DesignTokens.Spacing.sm) {
                                        Image(systemName: "app.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(workspace.swiftUIColor)

                                        Text(bundleId)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    }
                                }
                            }
                        }
                    }

                    // Project path
                    if let projectPath = workspace.projectPath, !projectPath.isEmpty {
                        DetailSection(title: "Project Path") {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(workspace.swiftUIColor)

                                Text(projectPath)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                            }
                        }
                    }

                    // Empty state
                    if workspace.appFilter.isEmpty && (workspace.projectPath?.isEmpty ?? true) {
                        VStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 48, weight: .ultraLight))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)

                            Text("No Auto-assignment Rules")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)

                            Text("Add apps or project paths to automatically organize clipboard items")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignTokens.Spacing.xl)

                            Button("Add Rules") {
                                editWorkspace(workspace)
                            }
                            .buttonStyle(GlassButtonStyle())
                            .padding(.top, DesignTokens.Spacing.sm)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(DesignTokens.Spacing.xxl)
                    }
                }
                .padding(DesignTokens.Spacing.xl)
            }
        }
    }

    // MARK: - Empty Selection

    private var emptySelection: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.textSecondary,
                            DesignTokens.Colors.textTertiary
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Select a Workspace")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("Choose a workspace to view or edit its settings")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createNewWorkspace() {
        editingWorkspace = Workspace(
            name: "New Workspace",
            color: WorkspaceService.randomColor
        )
        showingEditor = true
    }

    private func editWorkspace(_ workspace: Workspace) {
        editingWorkspace = workspace
        showingEditor = true
    }

    private func confirmDeleteWorkspace(_ workspace: Workspace) {
        guard workspace.id != Workspace.uncategorized.id else { return }

        withAnimation(DesignTokens.Animation.spring) {
            let success = workspaceService.deleteWorkspace(workspace)
            if success {
                toastManager.success("Workspace '\(workspace.name)' deleted")
                if selectedWorkspace?.id == workspace.id {
                    selectedWorkspace = workspaceService.workspaces.first
                }
            } else {
                toastManager.error("Failed to delete workspace")
            }
        }

        workspaceToDelete = nil
    }
}

// MARK: - Workspace List Item

private struct WorkspaceListItem: View {
    let workspace: Workspace
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Circle()
                    .fill(workspace.swiftUIColor)
                    .frame(width: 20, height: 20)
                    .shadow(color: workspace.swiftUIColor.opacity(0.3), radius: 4, x: 0, y: 2)

                Text(workspace.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)

                Spacer()

                if workspace.id == Workspace.uncategorized.id {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.0 : 0)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.quick) {
                isHovered = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return workspace.swiftUIColor.opacity(0.12)
        }
        return isHovered ? DesignTokens.Colors.surfaceSecondary.opacity(0.5) : Color.clear
    }

    private var borderColor: Color {
        if isSelected {
            return workspace.swiftUIColor.opacity(0.3)
        }
        return Color.clear
    }
}

// MARK: - Detail Section

private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .textCase(.uppercase)

            GlassCard(padding: DesignTokens.Spacing.md, intensity: .subtle) {
                content
            }
        }
    }
}

// MARK: - Preview

#Preview("Workspace Manager") {
    WorkspaceManagerView(workspaceService: WorkspaceService())
}
