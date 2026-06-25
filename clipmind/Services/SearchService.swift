//
//  SearchService.swift
//  clipmind
//
//  High-performance full-text search with advanced filtering and ranking
//

import Foundation
import Combine

/// Search result with ranking score
struct SearchResult: Identifiable {
    let id = UUID()
    let item: ClipboardItem
    let score: Double
    let matchedFields: Set<SearchField>
    let highlights: [SearchHighlight]
}

/// Field that matched the search
enum SearchField: String, CaseIterable {
    case content
    case sourceApp
    case windowTitle
    case workspaceName

    var weight: Double {
        switch self {
        case .content: return 1.0
        case .sourceApp: return 0.6
        case .windowTitle: return 0.5
        case .workspaceName: return 0.4
        }
    }
}

/// Highlighted text segment
struct SearchHighlight {
    let field: SearchField
    let range: Range<String.Index>
    let text: String
}

/// Search filter criteria
struct SearchFilter: Equatable {
    var query: String = ""
    var types: Set<ClipboardItemType> = []
    var sourceApps: Set<String> = []
    var workspaceIds: Set<UUID> = []
    var dateRange: DateRange?
    var isSensitiveOnly: Bool = false
    var hasWorkspace: Bool? = nil
    var minLength: Int? = nil
    var maxLength: Int? = nil

    var hasActiveFilters: Bool {
        !types.isEmpty || !sourceApps.isEmpty || !workspaceIds.isEmpty ||
        dateRange != nil || isSensitiveOnly || hasWorkspace != nil ||
        minLength != nil || maxLength != nil
    }
}

/// Date range filter
struct DateRange: Equatable {
    var start: Date?
    var end: Date?

    static let today = DateRange(
        start: Calendar.current.startOfDay(for: Date()),
        end: Date()
    )

    static let yesterday = DateRange(
        start: Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())),
        end: Calendar.current.startOfDay(for: Date())
    )

    static let lastWeek = DateRange(
        start: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
        end: Date()
    )

    static let lastMonth = DateRange(
        start: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
        end: Date()
    )

    static let lastYear = DateRange(
        start: Calendar.current.date(byAdding: .year, value: -1, to: Date()),
        end: Date()
    )
}

/// Search options
struct SearchOptions {
    var caseSensitive: Bool = false
    var wholeWord: Bool = false
    var fuzzyMatch: Bool = false
    var fuzzyThreshold: Double = 0.8
    var maxResults: Int = 500
    var sortBy: SearchSortOrder = .relevance
}

/// Search sort order
enum SearchSortOrder: String, CaseIterable {
    case relevance = "Relevance"
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case sourceApp = "Source App"
    case type = "Content Type"
}

/// High-performance search service
class SearchService: ObservableObject {
    static let shared = SearchService()

    @Published private(set) var recentSearches: [String] = []
    @Published private(set) var isSearching = false

    private let database = DatabaseService.shared
    private let searchQueue = DispatchQueue(label: "com.clipmind.search", qos: .userInitiated)

    // Search cache for performance
    private var searchCache: [String: [SearchResult]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.clipmind.searchcache", attributes: .concurrent)
    private let maxCacheSize = 50

    // Search history
    private let maxRecentSearches = 20
    private let recentSearchesKey = "recentSearches"

    private init() {
        loadRecentSearches()
    }

    // MARK: - Public API

    /// Perform search with filters and options
    func search(
        items: [ClipboardItem],
        filter: SearchFilter,
        options: SearchOptions = SearchOptions(),
        workspaces: [Workspace] = []
    ) async -> [SearchResult] {

        await setSearching(true)
        defer { Task { await setSearching(false) } }

        // Check cache if query hasn't changed
        let cacheKey = generateCacheKey(filter: filter, options: options)
        if let cached = getCachedResults(for: cacheKey), !filter.hasActiveFilters || filter.query.isEmpty {
            return cached
        }

        // Save search query
        if !filter.query.isEmpty {
            await saveSearchQuery(filter.query)
        }

        // Filter items first
        var filteredItems = items
        filteredItems = applyFilters(to: filteredItems, filter: filter, workspaces: workspaces)

        // If no query, return filtered items with default scores
        guard !filter.query.isEmpty else {
            let results = filteredItems.map { item in
                SearchResult(item: item, score: 1.0, matchedFields: [], highlights: [])
            }
            return sortResults(results, by: options.sortBy)
        }

        // Perform full-text search
        let results = performSearch(
            query: filter.query,
            items: filteredItems,
            options: options,
            workspaces: workspaces
        )

        // Cache results
        cacheResults(results, for: cacheKey)

        return results
    }

    /// Get search suggestions based on recent searches and current query
    func getSuggestions(for query: String, maxSuggestions: Int = 5) -> [String] {
        guard !query.isEmpty else {
            return Array(recentSearches.prefix(maxSuggestions))
        }

        let lowercased = query.lowercased()
        let matching = recentSearches.filter { $0.lowercased().contains(lowercased) }
        return Array(matching.prefix(maxSuggestions))
    }

    /// Clear search cache
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.searchCache.removeAll()
        }
    }

    /// Clear search history
    func clearHistory() {
        recentSearches.removeAll()
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }

    // MARK: - Private Search Methods

    /// Perform full-text search with ranking
    private func performSearch(
        query: String,
        items: [ClipboardItem],
        options: SearchOptions,
        workspaces: [Workspace]
    ) -> [SearchResult] {

        let searchTerms = tokenizeQuery(query, options: options)
        var results: [SearchResult] = []

        for item in items {
            if let result = scoreItem(item, searchTerms: searchTerms, options: options, workspaces: workspaces) {
                results.append(result)
            }
        }

        // Sort by score (descending) then by date
        results.sort { result1, result2 in
            if result1.score == result2.score {
                return result1.item.timestamp > result2.item.timestamp
            }
            return result1.score > result2.score
        }

        // Apply max results limit
        if results.count > options.maxResults {
            results = Array(results.prefix(options.maxResults))
        }

        // Sort by specified order
        return sortResults(results, by: options.sortBy)
    }

    /// Score an item against search terms
    private func scoreItem(
        _ item: ClipboardItem,
        searchTerms: [String],
        options: SearchOptions,
        workspaces: [Workspace]
    ) -> SearchResult? {

        var totalScore: Double = 0
        var matchedFields = Set<SearchField>()
        var highlights: [SearchHighlight] = []

        // Search in content
        let contentScore = searchInText(
            item.previewText,
            searchTerms: searchTerms,
            options: options,
            field: .content
        )
        if contentScore.score > 0 {
            totalScore += contentScore.score * SearchField.content.weight
            matchedFields.insert(.content)
            highlights.append(contentsOf: contentScore.highlights)
        }

        // Search in source app
        let appScore = searchInText(
            item.sourceApp,
            searchTerms: searchTerms,
            options: options,
            field: .sourceApp
        )
        if appScore.score > 0 {
            totalScore += appScore.score * SearchField.sourceApp.weight
            matchedFields.insert(.sourceApp)
            highlights.append(contentsOf: appScore.highlights)
        }

        // Search in window title
        if let windowTitle = item.windowTitle {
            let titleScore = searchInText(
                windowTitle,
                searchTerms: searchTerms,
                options: options,
                field: .windowTitle
            )
            if titleScore.score > 0 {
                totalScore += titleScore.score * SearchField.windowTitle.weight
                matchedFields.insert(.windowTitle)
                highlights.append(contentsOf: titleScore.highlights)
            }
        }

        // Search in workspace name
        if let workspaceId = item.workspaceId,
           let workspace = workspaces.first(where: { $0.id == workspaceId }) {
            let workspaceScore = searchInText(
                workspace.name,
                searchTerms: searchTerms,
                options: options,
                field: .workspaceName
            )
            if workspaceScore.score > 0 {
                totalScore += workspaceScore.score * SearchField.workspaceName.weight
                matchedFields.insert(.workspaceName)
                highlights.append(contentsOf: workspaceScore.highlights)
            }
        }

        // Return nil if no matches
        guard totalScore > 0 else { return nil }

        return SearchResult(
            item: item,
            score: totalScore,
            matchedFields: matchedFields,
            highlights: highlights
        )
    }

    /// Search in text and calculate score
    private func searchInText(
        _ text: String,
        searchTerms: [String],
        options: SearchOptions,
        field: SearchField
    ) -> (score: Double, highlights: [SearchHighlight]) {

        let searchText = options.caseSensitive ? text : text.lowercased()
        var score: Double = 0
        var highlights: [SearchHighlight] = []

        for term in searchTerms {
            let searchTerm = options.caseSensitive ? term : term.lowercased()

            if options.wholeWord {
                // Whole word matching
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: searchTerm))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: options.caseSensitive ? [] : .caseInsensitive) {
                    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                    score += Double(matches.count)

                    for match in matches {
                        if let range = Range(match.range, in: text) {
                            highlights.append(SearchHighlight(field: field, range: range, text: String(text[range])))
                        }
                    }
                }
            } else if options.fuzzyMatch {
                // Fuzzy matching
                let similarity = calculateSimilarity(searchTerm, searchText)
                if similarity >= options.fuzzyThreshold {
                    score += similarity
                }
            } else {
                // Simple substring matching
                if searchText.contains(searchTerm) {
                    // Count occurrences
                    var currentIndex = searchText.startIndex
                    while let range = searchText.range(of: searchTerm, range: currentIndex..<searchText.endIndex) {
                        score += 1.0

                        // Find corresponding range in original text
                        let offset = searchText.distance(from: searchText.startIndex, to: range.lowerBound)
                        let length = searchTerm.count
                        if let start = text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex),
                           let end = text.index(start, offsetBy: length, limitedBy: text.endIndex) {
                            highlights.append(SearchHighlight(field: field, range: start..<end, text: String(text[start..<end])))
                        }

                        currentIndex = range.upperBound
                    }

                    // Bonus for exact match
                    if searchText == searchTerm {
                        score += 2.0
                    }

                    // Bonus for starts with
                    if searchText.hasPrefix(searchTerm) {
                        score += 1.0
                    }
                }
            }
        }

        return (score, highlights)
    }

    /// Apply filters to items
    private func applyFilters(
        to items: [ClipboardItem],
        filter: SearchFilter,
        workspaces: [Workspace]
    ) -> [ClipboardItem] {

        return items.filter { item in
            // Type filter
            if !filter.types.isEmpty && !filter.types.contains(item.type) {
                return false
            }

            // Source app filter
            if !filter.sourceApps.isEmpty && !filter.sourceApps.contains(item.sourceApp) {
                return false
            }

            // Workspace filter
            if !filter.workspaceIds.isEmpty {
                guard let workspaceId = item.workspaceId,
                      filter.workspaceIds.contains(workspaceId) else {
                    return false
                }
            }

            // Has workspace filter
            if let hasWorkspace = filter.hasWorkspace {
                if hasWorkspace && item.workspaceId == nil {
                    return false
                }
                if !hasWorkspace && item.workspaceId != nil {
                    return false
                }
            }

            // Date range filter
            if let dateRange = filter.dateRange {
                if let start = dateRange.start, item.timestamp < start {
                    return false
                }
                if let end = dateRange.end, item.timestamp > end {
                    return false
                }
            }

            // Sensitive filter
            if filter.isSensitiveOnly && !item.isMarkedSensitive {
                return false
            }

            // Length filters
            let contentLength = item.previewText.count
            if let minLength = filter.minLength, contentLength < minLength {
                return false
            }
            if let maxLength = filter.maxLength, contentLength > maxLength {
                return false
            }

            return true
        }
    }

    /// Sort results by specified order
    private func sortResults(_ results: [SearchResult], by order: SearchSortOrder) -> [SearchResult] {
        switch order {
        case .relevance:
            return results // Already sorted by relevance

        case .dateNewest:
            return results.sorted { $0.item.timestamp > $1.item.timestamp }

        case .dateOldest:
            return results.sorted { $0.item.timestamp < $1.item.timestamp }

        case .sourceApp:
            return results.sorted { $0.item.sourceApp < $1.item.sourceApp }

        case .type:
            return results.sorted { $0.item.type.displayName < $1.item.type.displayName }
        }
    }

    /// Tokenize search query into terms
    private func tokenizeQuery(_ query: String, options: SearchOptions) -> [String] {
        // Split by whitespace and filter empty strings
        let terms = query.split(separator: " ").map { String($0) }.filter { !$0.isEmpty }
        return options.caseSensitive ? terms : terms.map { $0.lowercased() }
    }

    /// Calculate similarity between two strings (Levenshtein-based)
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = Array(str1)
        let s2 = Array(str2)

        guard !s1.isEmpty && !s2.isEmpty else { return 0 }

        let maxLength = max(s1.count, s2.count)
        let distance = levenshteinDistance(s1, s2)

        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Levenshtein distance (optimized)
    private func levenshteinDistance(_ s1: [Character], _ s2: [Character]) -> Int {
        var previousRow = Array(0...s2.count)
        var currentRow = Array(repeating: 0, count: s2.count + 1)

        for (i, char1) in s1.enumerated() {
            currentRow[0] = i + 1

            for (j, char2) in s2.enumerated() {
                let cost = char1 == char2 ? 0 : 1
                currentRow[j + 1] = min(
                    currentRow[j] + 1,
                    previousRow[j + 1] + 1,
                    previousRow[j] + cost
                )
            }

            swap(&previousRow, &currentRow)
        }

        return previousRow[s2.count]
    }

    // MARK: - Cache Management

    private func generateCacheKey(filter: SearchFilter, options: SearchOptions) -> String {
        "\(filter.query)_\(filter.types.count)_\(filter.sourceApps.count)_\(options.sortBy.rawValue)"
    }

    private func getCachedResults(for key: String) -> [SearchResult]? {
        cacheQueue.sync {
            return searchCache[key]
        }
    }

    private func cacheResults(_ results: [SearchResult], for key: String) {
        cacheQueue.async(flags: .barrier) {
            self.searchCache[key] = results

            // Trim cache if too large
            if self.searchCache.count > self.maxCacheSize {
                // Remove oldest entries (simplified - just remove first few)
                let keysToRemove = Array(self.searchCache.keys.prefix(10))
                keysToRemove.forEach { self.searchCache.removeValue(forKey: $0) }
            }
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private func setSearching(_ value: Bool) {
        isSearching = value
    }

    // MARK: - Search History

    private func saveSearchQuery(_ query: String) async {
        await MainActor.run {
            // Remove if already exists
            recentSearches.removeAll { $0 == query }

            // Add to front
            recentSearches.insert(query, at: 0)

            // Trim to max
            if recentSearches.count > maxRecentSearches {
                recentSearches = Array(recentSearches.prefix(maxRecentSearches))
            }

            // Save to UserDefaults
            UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
        }
    }

    private func loadRecentSearches() {
        if let saved = UserDefaults.standard.stringArray(forKey: recentSearchesKey) {
            recentSearches = saved
        }
    }
}
