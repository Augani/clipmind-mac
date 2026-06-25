//
//  SmartTaggingService.swift
//  clipmind
//
//  AI-powered smart tagging and workspace prediction
//

import Foundation
import NaturalLanguage
import Combine

/// Auto-tagging rule
struct AutoTagRule: Identifiable, Codable {
    let id: UUID
    var name: String
    var conditions: [TagCondition]
    var actions: [TagAction]
    var isEnabled: Bool
    var priority: Int

    init(
        id: UUID = UUID(),
        name: String,
        conditions: [TagCondition] = [],
        actions: [TagAction] = [],
        isEnabled: Bool = true,
        priority: Int = 0
    ) {
        self.id = id
        self.name = name
        self.conditions = conditions
        self.actions = actions
        self.isEnabled = isEnabled
        self.priority = priority
    }
}

/// Condition for auto-tagging
enum TagCondition: Equatable {
    case appEquals(String)
    case appContains(String)
    case windowTitleContains(String)
    case contentContains(String)
    case contentTypeIs(ClipboardItemType)
    case pathContains(String)
    case timeOfDay(TimeOfDay)
    case dayOfWeek(DayOfWeekPattern)

    func matches(item: ClipboardItem, context: TaggingContext) -> Bool {
        switch self {
        case .appEquals(let app):
            return item.sourceApp.lowercased() == app.lowercased()

        case .appContains(let substring):
            return item.sourceApp.lowercased().contains(substring.lowercased())

        case .windowTitleContains(let substring):
            return item.windowTitle?.lowercased().contains(substring.lowercased()) ?? false

        case .contentContains(let substring):
            return item.previewText.lowercased().contains(substring.lowercased())

        case .contentTypeIs(let type):
            return item.type == type

        case .pathContains(let substring):
            if case .file(let url) = item.content {
                return url.path.lowercased().contains(substring.lowercased())
            }
            return false

        case .timeOfDay(let time):
            let hour = Calendar.current.component(.hour, from: item.timestamp)
            return time.timeRange.contains(hour)

        case .dayOfWeek(let pattern):
            let weekday = Calendar.current.component(.weekday, from: item.timestamp)
            return pattern.weekdays.contains(weekday)
        }
    }
}

// MARK: - Codable Conformance

extension TagCondition: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .appEquals(let value):
            try container.encode("appEquals", forKey: .type)
            try container.encode(value, forKey: .value)
        case .appContains(let value):
            try container.encode("appContains", forKey: .type)
            try container.encode(value, forKey: .value)
        case .windowTitleContains(let value):
            try container.encode("windowTitleContains", forKey: .type)
            try container.encode(value, forKey: .value)
        case .contentContains(let value):
            try container.encode("contentContains", forKey: .type)
            try container.encode(value, forKey: .value)
        case .contentTypeIs(let value):
            try container.encode("contentTypeIs", forKey: .type)
            try container.encode(value.rawValue, forKey: .value)
        case .pathContains(let value):
            try container.encode("pathContains", forKey: .type)
            try container.encode(value, forKey: .value)
        case .timeOfDay(let value):
            try container.encode("timeOfDay", forKey: .type)
            try container.encode(value.rawValue, forKey: .value)
        case .dayOfWeek(let value):
            try container.encode("dayOfWeek", forKey: .type)
            try container.encode(value.rawValue, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "appEquals":
            self = .appEquals(try container.decode(String.self, forKey: .value))
        case "appContains":
            self = .appContains(try container.decode(String.self, forKey: .value))
        case "windowTitleContains":
            self = .windowTitleContains(try container.decode(String.self, forKey: .value))
        case "contentContains":
            self = .contentContains(try container.decode(String.self, forKey: .value))
        case "contentTypeIs":
            let rawValue = try container.decode(String.self, forKey: .value)
            guard let itemType = ClipboardItemType(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Invalid content type")
            }
            self = .contentTypeIs(itemType)
        case "pathContains":
            self = .pathContains(try container.decode(String.self, forKey: .value))
        case "timeOfDay":
            let rawValue = try container.decode(String.self, forKey: .value)
            guard let timeOfDay = TimeOfDay(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Invalid time of day")
            }
            self = .timeOfDay(timeOfDay)
        case "dayOfWeek":
            let rawValue = try container.decode(String.self, forKey: .value)
            guard let dayOfWeek = DayOfWeekPattern(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Invalid day of week")
            }
            self = .dayOfWeek(dayOfWeek)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown condition type")
        }
    }
}

/// Action to perform when rule matches
enum TagAction: Equatable {
    case assignToWorkspace(UUID)
    case addTag(String)
    case markAsSensitive
    case setType(ClipboardItemType)

    func apply(to item: inout ClipboardItem, workspaceService: WorkspaceService) {
        switch self {
        case .assignToWorkspace(let workspaceId):
            item.workspaceId = workspaceId

        case .addTag(let tag):
            // Tags would need to be added to ClipboardItem model
            // For now, this is a placeholder
            break

        case .markAsSensitive:
            item.isMarkedSensitive = true

        case .setType(let type):
            // Type is immutable, so this would need special handling
            break
        }
    }
}

extension TagAction: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .assignToWorkspace(let value):
            try container.encode("assignToWorkspace", forKey: .type)
            try container.encode(value, forKey: .value)
        case .addTag(let value):
            try container.encode("addTag", forKey: .type)
            try container.encode(value, forKey: .value)
        case .markAsSensitive:
            try container.encode("markAsSensitive", forKey: .type)
        case .setType(let value):
            try container.encode("setType", forKey: .type)
            try container.encode(value.rawValue, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "assignToWorkspace":
            self = .assignToWorkspace(try container.decode(UUID.self, forKey: .value))
        case "addTag":
            self = .addTag(try container.decode(String.self, forKey: .value))
        case "markAsSensitive":
            self = .markAsSensitive
        case "setType":
            let rawValue = try container.decode(String.self, forKey: .value)
            guard let itemType = ClipboardItemType(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Invalid content type")
            }
            self = .setType(itemType)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown action type")
        }
    }
}

/// Context for tagging decisions
struct TaggingContext {
    var recentApps: [String] = []
    var recentWorkspaces: [UUID] = []
    var currentProjectPath: String?
    var userCorrections: [TagCorrection] = []
}

/// User correction for learning
struct TagCorrection: Codable {
    let itemId: UUID
    let predictedWorkspace: UUID?
    let actualWorkspace: UUID?
    let timestamp: Date
    let sourceApp: String
    let windowTitle: String?
}

/// Prediction confidence
enum PredictionConfidence {
    case high      // >80%
    case medium    // 50-80%
    case low       // <50%
}

/// Workspace prediction result
struct WorkspacePrediction {
    let workspace: Workspace
    let confidence: Double
    let reason: String
}

/// Smart tagging service with ML-based predictions
class SmartTaggingService: ObservableObject {
    static let shared = SmartTaggingService()

    @Published var rules: [AutoTagRule] = []
    @Published var isLearningEnabled: Bool = true

    private let database = DatabaseService.shared
    private var context = TaggingContext()
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])

    // Learning data
    private var corrections: [TagCorrection] = []
    private let correctionsKey = "tagCorrections"
    private let rulesKey = "autoTagRules"

    private var appWorkspacePatterns: [String: [UUID: Int]] = [:]
    private var windowPatterns: [String: [UUID: Int]] = [:]
    private var patternsBuilt = false
    private let patternsQueue = DispatchQueue(label: "com.clipmind.smarttagging.patterns")

    private init() {
        loadRules()
        loadCorrections()
        buildPatternsFromCorrectionsOnly()
    }

    // MARK: - Public API

    /// Predict workspace for a clipboard item
    func predictWorkspace(for item: ClipboardItem, workspaces: [Workspace]) -> WorkspacePrediction? {
        guard !workspaces.isEmpty else { return nil }

        var scores: [(workspace: Workspace, score: Double, reason: String)] = []

        for workspace in workspaces {
            var score = 0.0
            var reasons: [String] = []

            // 1. Check app patterns (40% weight)
            if let appPatterns = appWorkspacePatterns[item.sourceApp],
               let count = appPatterns[workspace.id] {
                let total = appPatterns.values.reduce(0, +)
                let confidence = Double(count) / Double(total)
                score += confidence * 0.4
                if confidence > 0.5 {
                    reasons.append("App usage pattern (\(Int(confidence * 100))%)")
                }
            }

            // 2. Check window title patterns (30% weight)
            if let windowTitle = item.windowTitle {
                let keywords = extractKeywords(from: windowTitle)
                for keyword in keywords {
                    if let patterns = windowPatterns[keyword],
                       let count = patterns[workspace.id] {
                        let total = patterns.values.reduce(0, +)
                        let confidence = Double(count) / Double(total)
                        score += confidence * 0.3 / Double(keywords.count)
                        if confidence > 0.5 {
                            reasons.append("Window keyword '\(keyword)' (\(Int(confidence * 100))%)")
                        }
                    }
                }
            }

            // 3. Check workspace app filters (20% weight)
            if workspace.appFilter.contains(item.sourceApp) {
                score += 0.2
                reasons.append("Workspace app filter match")
            }

            // 4. Check recent usage (10% weight)
            if context.recentWorkspaces.first == workspace.id {
                score += 0.1
                reasons.append("Recently used workspace")
            }

            if score > 0 {
                scores.append((workspace, score, reasons.joined(separator: ", ")))
            }
        }

        // Return highest scoring workspace if confidence is reasonable
        if let best = scores.max(by: { $0.score < $1.score }), best.score >= 0.3 {
            return WorkspacePrediction(
                workspace: best.workspace,
                confidence: best.score,
                reason: best.reason
            )
        }

        return nil
    }

    /// Apply auto-tagging rules to an item
    func applyRules(to item: ClipboardItem, workspaceService: WorkspaceService) -> ClipboardItem {
        var modifiedItem = item

        // Sort rules by priority
        let sortedRules = rules.filter { $0.isEnabled }.sorted { $0.priority > $1.priority }

        for rule in sortedRules {
            // Check if all conditions match
            let allMatch = rule.conditions.allSatisfy { $0.matches(item: item, context: context) }

            if allMatch {
                // Apply all actions
                for action in rule.actions {
                    action.apply(to: &modifiedItem, workspaceService: workspaceService)
                }
            }
        }

        return modifiedItem
    }

    /// Smart tag a new clipboard item
    func smartTag(_ item: ClipboardItem, workspaceService: WorkspaceService) -> ClipboardItem {
        var tagged = item

        // 1. Apply manual rules first
        tagged = applyRules(to: tagged, workspaceService: workspaceService)

        if tagged.workspaceId == nil, isLearningEnabled {
            if let prediction = predictWorkspace(for: tagged, workspaces: workspaceService.workspaces), prediction.confidence > 0.5 {
                tagged.workspaceId = prediction.workspace.id
            }
        }

        updateContext(with: tagged)

        if tagged.workspaceId != nil {
            learnFromItem(tagged)
        }

        return tagged
    }

    func recordCorrection(
        itemId: UUID,
        predictedWorkspace: UUID?,
        actualWorkspace: UUID?,
        sourceApp: String,
        windowTitle: String?
    ) {
        guard isLearningEnabled else { return }

        let correction = TagCorrection(
            itemId: itemId,
            predictedWorkspace: predictedWorkspace,
            actualWorkspace: actualWorkspace,
            timestamp: Date(),
            sourceApp: sourceApp,
            windowTitle: windowTitle
        )

        corrections.append(correction)
        saveCorrections()
        addPatternForCorrection(correction)
    }

    /// Add a new auto-tag rule
    func addRule(_ rule: AutoTagRule) {
        rules.append(rule)
        saveRules()
        objectWillChange.send()
    }

    /// Update an existing rule
    func updateRule(_ rule: AutoTagRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRules()
            objectWillChange.send()
        }
    }

    /// Delete a rule
    func deleteRule(_ rule: AutoTagRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
        objectWillChange.send()
    }

    /// Clear all learned patterns
    func clearLearning() {
        corrections.removeAll()
        appWorkspacePatterns.removeAll()
        windowPatterns.removeAll()
        saveCorrections()
    }

    /// Get learning statistics
    func getLearningStats() -> (corrections: Int, appPatterns: Int, windowPatterns: Int) {
        return (
            corrections.count,
            appWorkspacePatterns.count,
            windowPatterns.count
        )
    }

    // MARK: - Private Methods

    /// Extract keywords from text using NLTagger
    private func extractKeywords(from text: String) -> [String] {
        tagger.string = text
        var keywords: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace]) { tag, range in
            if let tag = tag, tag == .noun || tag == .verb {
                let word = String(text[range]).lowercased()
                if word.count >= 3 { // Only meaningful words
                    keywords.append(word)
                }
            }
            return true
        }

        return keywords
    }

    private func buildPatternsFromCorrectionsOnly() {
        patternsQueue.async { [weak self] in
            guard let self = self else { return }

            for correction in self.corrections {
                guard let workspace = correction.actualWorkspace else { continue }
                self.appWorkspacePatterns[correction.sourceApp, default: [:]][workspace, default: 0] += 1

                if let windowTitle = correction.windowTitle {
                    let keywords = self.extractKeywords(from: windowTitle)
                    for keyword in keywords {
                        self.windowPatterns[keyword, default: [:]][workspace, default: 0] += 1
                    }
                }
            }
        }
    }

    private func addPatternForCorrection(_ correction: TagCorrection) {
        guard let workspace = correction.actualWorkspace else { return }

        patternsQueue.async { [weak self] in
            guard let self = self else { return }
            self.appWorkspacePatterns[correction.sourceApp, default: [:]][workspace, default: 0] += 1

            if let windowTitle = correction.windowTitle {
                let keywords = self.extractKeywords(from: windowTitle)
                for keyword in keywords {
                    self.windowPatterns[keyword, default: [:]][workspace, default: 0] += 1
                }
            }
        }
    }

    func learnFromItem(_ item: ClipboardItem) {
        guard let workspace = item.workspaceId else { return }

        patternsQueue.async { [weak self] in
            guard let self = self else { return }
            self.appWorkspacePatterns[item.sourceApp, default: [:]][workspace, default: 0] += 1

            if let windowTitle = item.windowTitle {
                let keywords = self.extractKeywords(from: windowTitle)
                for keyword in keywords {
                    self.windowPatterns[keyword, default: [:]][workspace, default: 0] += 1
                }
            }
        }
    }

    /// Update tagging context
    private func updateContext(with item: ClipboardItem) {
        // Track recent apps
        if !context.recentApps.contains(item.sourceApp) {
            context.recentApps.insert(item.sourceApp, at: 0)
            if context.recentApps.count > 10 {
                context.recentApps.removeLast()
            }
        }

        // Track recent workspaces
        if let workspaceId = item.workspaceId {
            if !context.recentWorkspaces.contains(workspaceId) {
                context.recentWorkspaces.insert(workspaceId, at: 0)
                if context.recentWorkspaces.count > 5 {
                    context.recentWorkspaces.removeLast()
                }
            }
        }
    }

    // MARK: - Persistence

    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let savedRules = try? JSONDecoder().decode([AutoTagRule].self, from: data) {
            rules = savedRules
        } else {
            // Create default rules
            createDefaultRules()
        }
    }

    private func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
    }

    private func loadCorrections() {
        if let data = UserDefaults.standard.data(forKey: correctionsKey),
           let saved = try? JSONDecoder().decode([TagCorrection].self, from: data) {
            corrections = saved
        }
    }

    private func saveCorrections() {
        if let data = try? JSONEncoder().encode(corrections) {
            UserDefaults.standard.set(data, forKey: correctionsKey)
        }
    }

    private func createDefaultRules() {
        // Rule: Code snippets from Xcode/VSCode
        let codeRule = AutoTagRule(
            name: "Code Snippets",
            conditions: [
                .appContains("Xcode"),
                .contentTypeIs(.code)
            ],
            actions: [],
            priority: 10
        )

        // Rule: Terminal commands
        let terminalRule = AutoTagRule(
            name: "Terminal Commands",
            conditions: [
                .appEquals("Terminal")
            ],
            actions: [],
            priority: 9
        )

        // Rule: Sensitive content
        let sensitiveRule = AutoTagRule(
            name: "Mark API Keys as Sensitive",
            conditions: [
                .contentContains("API_KEY"),
                .contentContains("SECRET")
            ],
            actions: [
                .markAsSensitive
            ],
            priority: 100
        )

        rules = [codeRule, terminalRule, sensitiveRule]
        saveRules()
    }
}
