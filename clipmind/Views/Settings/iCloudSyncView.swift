//
//  iCloudSyncView.swift
//  clipmind
//
//  iCloud sync settings and status UI
//

import SwiftUI

struct iCloudSyncView: View {
    @StateObject private var syncService = iCloudSyncService.shared
    @State private var showingConflictSheet = false
    @State private var isEnabling = false
    @State private var selectedResolution: ConflictResolution = .keepNewest

    var body: some View {
        Form {
            // Sync Status Section
            Section("iCloud Sync") {
                VStack(alignment: .leading, spacing: 12) {
                    // Enable/Disable Toggle
                    Toggle("Enable iCloud Sync", isOn: Binding(
                        get: { syncService.isEnabled },
                        set: { enabled in
                            if enabled {
                                enableSync()
                            } else {
                                syncService.disableSync()
                            }
                        }
                    ))
                    .disabled(isEnabling)

                    if syncService.isEnabled {
                        Divider()

                        // Sync Status
                        HStack {
                            Image(systemName: syncStatusIcon)
                                .foregroundStyle(syncStatusColor)
                            Text(syncStatusText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        // Last Sync Time
                        if let lastSync = syncService.stats.lastSyncDate {
                            HStack {
                                Text("Last synced:")
                                Spacer()
                                Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 12))
                        }

                        // Sync Progress
                        if case .syncing = syncService.syncState {
                            VStack(spacing: 4) {
                                ProgressView(value: syncService.syncProgress)
                                Text("Syncing...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if syncService.isEnabled {
                // Statistics Section
                Section("Sync Statistics") {
                    VStack(alignment: .leading, spacing: 8) {
                        StatRow(
                            label: "Items Uploaded",
                            value: "\(syncService.stats.itemsUploaded)",
                            icon: "arrow.up.circle"
                        )

                        StatRow(
                            label: "Items Downloaded",
                            value: "\(syncService.stats.itemsDownloaded)",
                            icon: "arrow.down.circle"
                        )

                        StatRow(
                            label: "Conflicts Resolved",
                            value: "\(syncService.stats.conflictsResolved)",
                            icon: "exclamationmark.triangle"
                        )

                        StatRow(
                            label: "Sync Errors",
                            value: "\(syncService.stats.syncErrors)",
                            icon: "xmark.circle"
                        )
                    }
                }

                // Conflict Resolution Section
                Section("Conflict Resolution") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When the same item is modified on multiple devices:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Resolution Strategy", selection: Binding(
                            get: { syncService.conflictResolution },
                            set: { syncService.conflictResolution = $0 }
                        )) {
                            Text("Keep Newest").tag(ConflictResolution.keepNewest)
                            Text("Keep Local").tag(ConflictResolution.keepLocal)
                            Text("Keep Remote").tag(ConflictResolution.keepRemote)
                            Text("Keep Both").tag(ConflictResolution.keepBoth)
                            Text("Ask Me").tag(ConflictResolution.askUser)
                        }
                        .pickerStyle(.menu)

                        if !syncService.conflicts.isEmpty {
                            HStack {
                                Text("\(syncService.conflicts.count) unresolved conflict(s)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.orange)

                                Spacer()

                                Button("Review") {
                                    showingConflictSheet = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                // Actions Section
                Section("Actions") {
                    VStack(spacing: 8) {
                        Button(action: syncNow) {
                            HStack {
                                if case .syncing = syncService.syncState {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 4)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text("Sync Now")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSyncing)
                    }
                }

                // Information Section
                Section("Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Clipboard items are synced across all your devices", systemImage: "icloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("Sensitive items are encrypted before syncing", systemImage: "lock.shield")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("Changes are pushed automatically in real-time", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showingConflictSheet) {
            ConflictResolutionSheet()
        }
    }

    // MARK: - Helper Properties

    private var isSyncing: Bool {
        if case .syncing = syncService.syncState {
            return true
        }
        return false
    }

    private var syncStatusIcon: String {
        switch syncService.syncState {
        case .idle:
            return "checkmark.circle"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .paused:
            return "pause.circle"
        }
    }

    private var syncStatusColor: Color {
        switch syncService.syncState {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .paused:
            return .orange
        }
    }

    private var syncStatusText: String {
        switch syncService.syncState {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .completed:
            return "Sync completed"
        case .failed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .paused:
            return "Sync paused"
        }
    }

    // MARK: - Actions

    private func enableSync() {
        isEnabling = true

        Task {
            do {
                try await syncService.enableSync()
                await MainActor.run {
                    isEnabling = false
                    ToastManager.shared.success("iCloud sync enabled")
                }
            } catch {
                await MainActor.run {
                    isEnabling = false
                    ToastManager.shared.error("Failed to enable sync: \(error.localizedDescription)")
                }
            }
        }
    }

    private func syncNow() {
        Task {
            do {
                try await syncService.performSync()
            } catch {
                await MainActor.run {
                    ToastManager.shared.error("Sync failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Conflict Resolution Sheet

struct ConflictResolutionSheet: View {
    @StateObject private var syncService = iCloudSyncService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync Conflicts")
                        .font(.system(size: 20, weight: .bold))

                    Text("Choose which version to keep")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Conflicts List
            if syncService.conflicts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("No Conflicts")
                        .font(.system(size: 18, weight: .semibold))

                    Text("All items are in sync")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(syncService.conflicts) { conflict in
                            ConflictRow(conflict: conflict)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 700, height: 500)
        .background(VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow))
    }
}

// MARK: - Conflict Row

struct ConflictRow: View {
    let conflict: SyncConflict
    @StateObject private var syncService = iCloudSyncService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Conflict Info
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("Modified on multiple devices")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }

            HStack(spacing: 16) {
                // Local Version
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "laptopcomputer")
                            .foregroundStyle(.blue)
                        Text("Local")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    Text(conflict.localItem.firstLine)
                        .font(.system(size: 12))
                        .lineLimit(3)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )

                    Text(conflict.localItem.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Button("Keep Local") {
                        resolveConflict(.keepLocal)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider()

                // Remote Version
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "icloud")
                            .foregroundStyle(.purple)
                        Text("iCloud")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.purple)
                    }

                    Text(conflict.remoteItem.firstLine)
                        .font(.system(size: 12))
                        .lineLimit(3)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple.opacity(0.1))
                        )

                    Text(conflict.remoteItem.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Button("Keep iCloud") {
                        resolveConflict(.keepRemote)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Additional Actions
            HStack {
                Button("Keep Both") {
                    resolveConflict(.keepBoth)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if conflict.localItem.timestamp > conflict.remoteItem.timestamp {
                    Button("Keep Newest (Local)") {
                        resolveConflict(.keepNewest)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("Keep Newest (iCloud)") {
                        resolveConflict(.keepNewest)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.Colors.glassPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private func resolveConflict(_ resolution: ConflictResolution) {
        Task {
            do {
                try await syncService.resolveConflict(conflict, resolution: resolution)
                ToastManager.shared.success("Conflict resolved")
            } catch {
                ToastManager.shared.error("Failed to resolve conflict: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    iCloudSyncView()
}
