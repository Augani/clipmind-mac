//
//  CleanupSettingsView.swift
//  clipmind
//
//  Settings UI for cleanup and deduplication
//

import SwiftUI

struct CleanupSettingsView: View {
    @StateObject private var cleanupService = CleanupService.shared
    @State private var policy: RetentionPolicy
    @State private var isRunningCleanup = false
    @State private var cleanupStats: CleanupStats?

    init() {
        _policy = State(initialValue: CleanupService.shared.policy)
    }

    var body: some View {
        Form {
            // Retention Policy Section
            Section("Retention Policy") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Toggle("Enable automatic cleanup", isOn: $policy.enableAutoCleanup)

                    HStack {
                        Text("Maximum items:")
                        Spacer()
                        TextField("", value: $policy.maxItems, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Delete items older than:")
                        Spacer()
                        TextField("", value: $policy.maxDays, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("days")
                    }

                    HStack {
                        Text("Archive items after:")
                        Spacer()
                        TextField("", value: $policy.archiveAfterDays, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("days")
                    }

                    HStack {
                        Text("Delete sensitive items after:")
                        Spacer()
                        TextField("", value: $policy.autoDeleteSensitiveAfterHours, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("hours")
                    }

                    HStack {
                        Text("Low disk space threshold:")
                        Spacer()
                        TextField("", value: $policy.lowDiskSpaceThresholdMB, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                        Text("MB")
                    }

                    Button("Save Policy") {
                        cleanupService.savePolicy(policy)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(policy == cleanupService.policy)
                }
            }

            // Cleanup Stats Section
            Section("Cleanup Statistics") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    if let lastCleanup = cleanupService.stats.lastCleanupDate {
                        HStack {
                            Text("Last cleanup:")
                            Spacer()
                            Text(lastCleanup.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let nextCleanup = cleanupService.stats.nextScheduledCleanup {
                        HStack {
                            Text("Next scheduled:")
                            Spacer()
                            Text(nextCleanup.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Database size:")
                        Spacer()
                        Text(String(format: "%.2f MB", cleanupService.getDatabaseSizeMB()))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Available disk space:")
                        Spacer()
                        Text(String(format: "%.2f MB", cleanupService.getAvailableDiskSpaceMB()))
                            .foregroundStyle(.secondary)
                    }

                    if let stats = cleanupStats {
                        Divider()

                        HStack {
                            Text("Items deleted:")
                            Spacer()
                            Text("\(stats.itemsDeleted)")
                                .foregroundStyle(.red)
                        }

                        HStack {
                            Text("Items archived:")
                            Spacer()
                            Text("\(stats.itemsArchived)")
                                .foregroundStyle(.orange)
                        }

                        HStack {
                            Text("Space freed:")
                            Spacer()
                            Text(String(format: "%.2f MB", stats.diskSpaceFreedMB))
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            // Actions Section
            Section("Actions") {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Button(action: runCleanupNow) {
                        HStack {
                            if isRunningCleanup {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "trash.circle")
                            }
                            Text(isRunningCleanup ? "Running cleanup..." : "Run Cleanup Now")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunningCleanup)
                }
            }

            // Information Section
            Section("Information") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Label("Automatic cleanup runs daily at 3:00 AM", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("Sensitive items are auto-deleted based on security settings", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("Emergency cleanup triggers when disk space is low", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func runCleanupNow() {
        isRunningCleanup = true

        Task {
            let stats = await cleanupService.runCleanup()

            await MainActor.run {
                cleanupStats = stats
                isRunningCleanup = false
            }
        }
    }
}

#Preview {
    CleanupSettingsView()
}
