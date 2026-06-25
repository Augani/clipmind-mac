//
//  AutoTaggingView.swift
//  clipmind
//
//  Auto-tagging rules and smart prediction settings
//

import SwiftUI

struct AutoTaggingView: View {
    @StateObject private var taggingService = SmartTaggingService.shared
    @State private var showingRuleEditor = false
    @State private var editingRule: AutoTagRule?
    @State private var learningStats = SmartTaggingService.shared.getLearningStats()

    var body: some View {
        Form {
            // Smart Predictions Section
            Section("Smart Predictions") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable AI-powered workspace prediction", isOn: $taggingService.isLearningEnabled)

                    Text("ClipMind learns from your clipboard usage patterns to automatically suggest the right workspace for new items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    // Learning Statistics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Learning Progress")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        StatRow(
                            label: "User Corrections",
                            value: "\(learningStats.corrections)",
                            icon: "arrow.triangle.branch"
                        )

                        StatRow(
                            label: "App Patterns",
                            value: "\(learningStats.appPatterns)",
                            icon: "app.fill"
                        )

                        StatRow(
                            label: "Window Patterns",
                            value: "\(learningStats.windowPatterns)",
                            icon: "macwindow"
                        )
                    }

                    if taggingService.isLearningEnabled {
                        Button("Clear Learning Data") {
                            taggingService.clearLearning()
                            refreshStats()
                            ToastManager.shared.success("Learning data cleared")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            // Auto-Tag Rules Section
            Section("Auto-Tag Rules") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(taggingService.rules.count) rule(s)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: { showingRuleEditor = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add Rule")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    if taggingService.rules.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tag")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)

                            Text("No Auto-Tag Rules")
                                .font(.system(size: 13, weight: .medium))

                            Text("Create rules to automatically organize clipboard items")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(taggingService.rules) { rule in
                                RuleRow(rule: rule) {
                                    editingRule = rule
                                    showingRuleEditor = true
                                }
                            }
                        }
                    }
                }
            }

            // Information Section
            Section("How It Works") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI learns from your clipboard usage patterns", systemImage: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("Rules are applied in priority order", systemImage: "list.number")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("Manual workspace changes help improve predictions", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showingRuleEditor) {
            RuleEditorSheet(rule: editingRule) { newRule in
                if let editing = editingRule {
                    taggingService.updateRule(newRule)
                } else {
                    taggingService.addRule(newRule)
                }
                editingRule = nil
            }
        }
        .onChange(of: showingRuleEditor) { newValue in
            if !newValue {
                editingRule = nil
            }
        }
        .onAppear {
            refreshStats()
        }
    }

    private func refreshStats() {
        learningStats = taggingService.getLearningStats()
    }
}

// MARK: - Rule Row

struct RuleRow: View {
    let rule: AutoTagRule
    let onEdit: () -> Void
    @StateObject private var taggingService = SmartTaggingService.shared

    var body: some View {
        HStack(spacing: 12) {
            // Enabled indicator
            Circle()
                .fill(rule.isEnabled ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 4) {
                    Text("\(rule.conditions.count) condition(s)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text("\(rule.actions.count) action(s)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if rule.priority > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)

                        Text("Priority: \(rule.priority)")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: {
                taggingService.deleteRule(rule)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rule.isEnabled ? DesignTokens.Colors.surfaceSecondary.opacity(0.3) : Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Rule Editor Sheet

struct RuleEditorSheet: View {
    let rule: AutoTagRule?
    let onSave: (AutoTagRule) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var conditions: [TagCondition] = []
    @State private var actions: [TagAction] = []
    @State private var isEnabled: Bool
    @State private var priority: Int

    init(rule: AutoTagRule?, onSave: @escaping (AutoTagRule) -> Void) {
        self.rule = rule
        self.onSave = onSave

        _name = State(initialValue: rule?.name ?? "New Rule")
        _conditions = State(initialValue: rule?.conditions ?? [])
        _actions = State(initialValue: rule?.actions ?? [])
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
        _priority = State(initialValue: rule?.priority ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(rule == nil ? "New Auto-Tag Rule" : "Edit Rule")
                    .font(.system(size: 20, weight: .bold))

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

            // Content
            Form {
                Section("Rule Settings") {
                    TextField("Rule Name", text: $name)

                    Toggle("Enabled", isOn: $isEnabled)

                    Stepper("Priority: \(priority)", value: $priority, in: 0...100)
                        .help("Higher priority rules are applied first")
                }

                Section("Conditions (all must match)") {
                    Text("Items matching these conditions will trigger this rule")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Placeholder for conditions editor
                    Text("Condition editor UI would go here")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

                Section("Actions") {
                    Text("Actions to perform when conditions match")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Placeholder for actions editor
                    Text("Action editor UI would go here")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .background(VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow))
    }

    private func save() {
        let newRule = AutoTagRule(
            id: rule?.id ?? UUID(),
            name: name,
            conditions: conditions,
            actions: actions,
            isEnabled: isEnabled,
            priority: priority
        )

        onSave(newRule)
        dismiss()
    }
}

#Preview {
    AutoTaggingView()
}
