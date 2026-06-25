//
//  DashboardView.swift
//  clipmind
//
//  Lean, day-grouped timeline dashboard
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var clipboardStore: ClipboardStore
    @StateObject private var multiPasteService = MultiPasteService.shared
    @StateObject private var toastManager = ToastManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var searchText = ""
    @State private var selectedType: ClipboardItemType?
    @State private var selectedWorkspace: UUID?
    @State private var originFilter: ClipboardOrigin?
    @State private var sourceAppFilter: String?
    @State private var timeOfDay: TimeOfDay?
    @State private var datePreset: DatePreset = .all
    @State private var customRange: DateRange?
    @State private var showCustomDate = false
    @State private var customStart = Date().addingTimeInterval(-7 * 86_400)
    @State private var customEnd = Date()

    @State private var selectedItem: ClipboardItem?
    @State private var itemToDelete: ClipboardItem?
    @State private var showingWorkspaceManager = false
    @State private var showingKeyboardShortcuts = false
    @State private var showOnboarding = false
    @State private var isLoading = true
    @State private var searchResults: [SearchResult] = []
    @State private var searchTask: Task<Void, Never>?

    enum DatePreset: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case yesterday = "Yesterday"
        case week = "This Week"

        var id: String { rawValue }

        var dateRange: DateRange? {
            switch self {
            case .all: return nil
            case .today: return .today
            case .yesterday: return .yesterday
            case .week: return .lastWeek
            }
        }
    }

    private var dbFilterActive: Bool {
        !searchText.isEmpty || selectedType != nil || selectedWorkspace != nil || datePreset != .all || customRange != nil
    }

    private var baseItems: [ClipboardItem] {
        if dbFilterActive {
            return searchResults.map { $0.item }
        }
        return clipboardStore.items.sorted { $0.timestamp > $1.timestamp }
    }

    private var displayItems: [ClipboardItem] {
        var items = baseItems
        if let origin = originFilter {
            items = items.filter { $0.origin == origin }
        }
        if let app = sourceAppFilter {
            items = items.filter { $0.sourceApp == app }
        }
        if let tod = timeOfDay {
            let calendar = Calendar.current
            items = items.filter { tod.timeRange.contains(calendar.component(.hour, from: $0.timestamp)) }
        }
        return items
    }

    private var sections: [DaySection] { groupByDay(displayItems) }

    private var distinctSourceApps: [String] {
        Array(Set(clipboardStore.items.map { $0.sourceApp })).sorted()
    }

    private var hasActiveFilters: Bool {
        dbFilterActive || originFilter != nil || sourceAppFilter != nil || timeOfDay != nil
    }

    private var currentWorkspaceName: String {
        if let id = selectedWorkspace, let workspace = clipboardStore.workspaceService.workspace(withId: id) {
            return workspace.name
        }
        return "Workspaces"
    }

    var body: some View {
        VStack(spacing: 0) {
            dashboardHeader
            searchField
            filterBar
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.top, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.md)

            Divider().overlay(DesignTokens.Colors.borderSubtle)

            if displayItems.isEmpty {
                emptyState
            } else {
                timelineList
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow))
        .overlay { if isLoading { loadingOverlay } }
        .overlay(alignment: .bottom) { if multiPasteService.isPasting { multiPasteBanner } }
        .sheet(isPresented: $showingWorkspaceManager) {
            WorkspaceManagerView(workspaceService: clipboardStore.workspaceService)
        }
        .sheet(isPresented: $showingKeyboardShortcuts) { KeyboardShortcutsView() }
        .sheet(isPresented: $showOnboarding) { OnboardingView(isPresented: $showOnboarding) }
        .sheet(item: $selectedItem) { item in ClipboardItemDetailView(item: item) }
        .alert("Delete Item", isPresented: .constant(itemToDelete != nil), presenting: itemToDelete) { item in
            Button("Cancel", role: .cancel) { itemToDelete = nil }
            Button("Delete", role: .destructive) { deleteItem(item) }
        } message: { _ in
            Text("Are you sure you want to delete this clipboard item? This action cannot be undone.")
        }
        .toast()
        .onAppear {
            if OnboardingManager.shared.shouldShowOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showOnboarding = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { isLoading = false }
                performSearch()
            }
        }
        .onChange(of: searchText) { _ in performSearch() }
        .onChange(of: selectedType) { _ in performSearch() }
        .onChange(of: selectedWorkspace) { _ in performSearch() }
        .onChange(of: datePreset) { _ in performSearch() }
        .onChange(of: customRange) { _ in performSearch() }
        .onChange(of: clipboardStore.items.count) { _ in performSearch() }
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            AppLogo(size: .small, showShadow: false)

            VStack(alignment: .leading, spacing: 2) {
                Text("ClipMind")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text("\(clipboardStore.totalItemCount) clipboard items")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            workspaceMenu
            headerButton("command", help: "Keyboard Shortcuts") { showingKeyboardShortcuts = true }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    private var workspaceMenu: some View {
        Menu {
            Button("All workspaces") { selectedWorkspace = nil }
            Divider()
            ForEach(clipboardStore.workspaceService.workspaces) { workspace in
                Button {
                    selectedWorkspace = selectedWorkspace == workspace.id ? nil : workspace.id
                } label: {
                    HStack {
                        Circle().fill(workspace.swiftUIColor).frame(width: 8, height: 8)
                        Text(workspace.name)
                        if selectedWorkspace == workspace.id { Image(systemName: "checkmark") }
                    }
                }
            }
            Divider()
            Button("Manage workspaces…") { showingWorkspaceManager = true }
        } label: {
            chipLabel(currentWorkspaceName, selected: selectedWorkspace != nil, icon: "rectangle.3.group")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func headerButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DesignTokens.Colors.surfaceSecondary.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            TextField("Search your clipboard…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular))

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
        )
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                groupLabel("WHEN")
                ForEach(DatePreset.allCases) { preset in
                    chip(preset.rawValue, selected: datePreset == preset && customRange == nil) {
                        datePreset = preset
                        customRange = nil
                    }
                }
                customDateChip
                timeOfDayMenu

                chipDivider

                groupLabel("TYPE")
                chip("All", selected: selectedType == nil) { selectedType = nil }
                ForEach(ClipboardItemType.allCases, id: \.self) { type in
                    chip(type.displayName, selected: selectedType == type, color: type.color) {
                        selectedType = selectedType == type ? nil : type
                    }
                }

                chipDivider

                groupLabel("DEVICE")
                chip("All", selected: originFilter == nil) { originFilter = nil }
                chip("Mac", selected: originFilter == .local, icon: "desktopcomputer") { originFilter = .local }
                chip("iPhone", selected: originFilter == .universalClipboard, icon: "iphone") { originFilter = .universalClipboard }

                chipDivider

                sourceAppMenu

                if hasActiveFilters {
                    chipDivider
                    Button(action: clearAllFilters) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                            Text("Clear").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(DesignTokens.Colors.error)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var customDateChip: some View {
        Button { showCustomDate.toggle() } label: {
            chipLabel(customRange == nil ? "Custom" : "Custom range", selected: customRange != nil, icon: "calendar")
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showCustomDate, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DatePicker("From", selection: $customStart, displayedComponents: [.date])
                DatePicker("To", selection: $customEnd, displayedComponents: [.date])
                HStack {
                    Button("Clear") {
                        customRange = nil
                        showCustomDate = false
                    }
                    Spacer()
                    Button("Apply") {
                        customRange = DateRange(start: customStart, end: customEnd)
                        datePreset = .all
                        showCustomDate = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(width: 260)
        }
    }

    private var timeOfDayMenu: some View {
        Menu {
            Button("Any time") { timeOfDay = nil }
            ForEach(TimeOfDay.allCases, id: \.self) { tod in
                Button {
                    timeOfDay = timeOfDay == tod ? nil : tod
                } label: {
                    HStack {
                        Image(systemName: tod.icon)
                        Text(tod.rawValue)
                        if timeOfDay == tod { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            chipLabel(timeOfDay?.rawValue ?? "Time", selected: timeOfDay != nil, icon: "clock")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var sourceAppMenu: some View {
        Menu {
            Button("All apps") { sourceAppFilter = nil }
            Divider()
            ForEach(distinctSourceApps, id: \.self) { app in
                Button {
                    sourceAppFilter = sourceAppFilter == app ? nil : app
                } label: {
                    HStack {
                        Text(app)
                        if sourceAppFilter == app { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            chipLabel(sourceAppFilter ?? "Source app", selected: sourceAppFilter != nil, icon: "app.badge")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func chip(_ title: String, selected: Bool, color: Color? = nil, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            chipLabel(title, selected: selected, color: color, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func chipLabel(_ title: String, selected: Bool, color: Color? = nil, icon: String? = nil) -> some View {
        let accent = color ?? DesignTokens.Colors.accentPrimary
        return HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .medium))
            }
            Text(title).font(.system(size: 11, weight: selected ? .semibold : .medium))
        }
        .foregroundStyle(selected ? accent : DesignTokens.Colors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(selected ? accent.opacity(0.16) : DesignTokens.Colors.surfaceSecondary.opacity(0.4)))
        .overlay(Capsule().strokeBorder(selected ? accent.opacity(0.4) : Color.clear, lineWidth: 0.5))
        .fixedSize()
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textTertiary)
    }

    private var chipDivider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.borderSubtle)
            .frame(width: 0.5, height: 16)
            .padding(.horizontal, 2)
    }

    // MARK: - Timeline

    private var timelineList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack(spacing: 6) {
                            Text(section.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                            Text("\(section.items.count)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                            Spacer()
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.top, DesignTokens.Spacing.xs)

                        ForEach(section.items) { item in
                            TimelineItemRow(
                                item: item,
                                onTap: { selectedItem = item },
                                onCopy: {
                                    clipboardStore.copyItemToClipboard(item)
                                    toastManager.success("Copied to clipboard")
                                },
                                onDelete: { itemToDelete = item }
                            )
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                        }
                    }
                }

                if clipboardStore.hasMoreItems && !dbFilterActive {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .onAppear { clipboardStore.loadMoreItems() }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.lg)
            .animation(reduceMotion ? nil : DesignTokens.Animation.smooth, value: displayItems.count)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: hasActiveFilters ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(hasActiveFilters ? "No matches" : "No clipboard items")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(emptyMessage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                if hasActiveFilters {
                    Button("Clear filters", action: clearAllFilters)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.accentPrimary)
                        .padding(.top, DesignTokens.Spacing.xs)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xxl)
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "No copies match “\(searchText)”. Try a different word or clear the filters."
        }
        if hasActiveFilters {
            return "Nothing matches the current filters."
        }
        return "Copy something to get started."
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: DesignTokens.Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(DesignTokens.Colors.accentPrimary)
                Text("Loading clipboard history…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }
            .padding(DesignTokens.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                    .fill(DesignTokens.Colors.glassPrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }

    // MARK: - Multi-Paste Banner

    private var multiPasteBanner: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ProgressView(value: multiPasteService.currentProgress).frame(width: 80)

            VStack(alignment: .leading, spacing: 2) {
                Text(multiPasteService.progressText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text("Multi-paste in progress")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Button("Cancel") {
                multiPasteService.cancelPasting()
                toastManager.warning("Multi-paste cancelled")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                    .fill(DesignTokens.Colors.glassPrimary)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: -4)
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.bottom, DesignTokens.Spacing.xl)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func clearAllFilters() {
        searchText = ""
        selectedType = nil
        selectedWorkspace = nil
        originFilter = nil
        sourceAppFilter = nil
        timeOfDay = nil
        datePreset = .all
        customRange = nil
    }

    private func buildSearchFilter() -> SearchFilter {
        var filter = SearchFilter()
        if let type = selectedType { filter.types = [type] }
        if let workspaceId = selectedWorkspace { filter.workspaceIds = [workspaceId] }
        if let range = customRange {
            filter.dateRange = range
        } else if let range = datePreset.dateRange {
            filter.dateRange = range
        }
        return filter
    }

    private func performSearch() {
        searchTask?.cancel()
        let query = searchText
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let filter = buildSearchFilter()
            let options = SearchOptions(sortBy: .dateNewest)
            let results = await clipboardStore.searchDatabase(
                query: query.isEmpty ? nil : query,
                filter: filter,
                options: options
            )
            guard !Task.isCancelled else { return }
            searchResults = results
        }
    }

    private func deleteItem(_ item: ClipboardItem) {
        clipboardStore.deleteItem(item)
        toastManager.success("Item deleted")
        itemToDelete = nil
    }
}

#Preview("Dashboard") {
    DashboardView()
        .environmentObject(ClipboardStore())
        .frame(width: 1000, height: 700)
}
