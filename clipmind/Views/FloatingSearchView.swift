//
//  FloatingSearchView.swift
//  clipmind
//
//  Floating search panel for quick clipboard access
//

import SwiftUI
import AppKit
import Combine

struct FloatingSearchView: View {
    @EnvironmentObject var clipboardStore: ClipboardStore
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFieldFocused: Bool

    @State private var selectedTimeFilter: QuickTimeFilter? = nil
    @State private var selectedSourceApp: String? = nil
    @State private var selectedContentType: ClipboardItemType? = nil
    @State private var showFilters = true

    let onClose: () -> Void
    let onItemSelected: (ClipboardItem) -> Void

    private var hasActiveFilters: Bool {
        selectedTimeFilter != nil || selectedSourceApp != nil || selectedContentType != nil
    }

    var filteredItems: [ClipboardItem] {
        var items = clipboardStore.items

        if let timeFilter = selectedTimeFilter {
            items = applyTimeFilter(items, filter: timeFilter)
        }

        if let sourceApp = selectedSourceApp {
            items = items.filter { $0.sourceApp.lowercased().contains(sourceApp.lowercased()) }
        }

        if let contentType = selectedContentType {
            items = items.filter { $0.type == contentType }
        }

        if !searchText.isEmpty {
            items = clipboardStore.searchInItems(searchText, items: items)
        }

        return Array(items.prefix(15))
    }

    private func applyTimeFilter(_ items: [ClipboardItem], filter: QuickTimeFilter) -> [ClipboardItem] {
        let calendar = Calendar.current
        let now = Date()

        switch filter {
        case .today:
            return items.filter { calendar.isDateInToday($0.timestamp) }
        case .yesterday:
            return items.filter { calendar.isDateInYesterday($0.timestamp) }
        case .thisWeek:
            return items.filter { calendar.isDate($0.timestamp, equalTo: now, toGranularity: .weekOfYear) }
        case .morning:
            return items.filter { $0.timeCategory == .morning && calendar.isDateInToday($0.timestamp) }
        case .afternoon:
            return items.filter { $0.timeCategory == .afternoon && calendar.isDateInToday($0.timestamp) }
        case .evening:
            return items.filter { $0.timeCategory == .evening && calendar.isDateInToday($0.timestamp) }
        }
    }

    private var recentSourceApps: [String] {
        var apps = Set<String>()
        for item in clipboardStore.items.prefix(50) {
            apps.insert(item.sourceApp)
            if apps.count >= 5 { break }
        }
        return Array(apps).sorted()
    }

    private var quickFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(QuickTimeFilter.allCases, id: \.self) { filter in
                    QuickFilterChip(
                        title: filter.displayName,
                        icon: filter.icon,
                        isSelected: selectedTimeFilter == filter
                    ) {
                        if selectedTimeFilter == filter {
                            selectedTimeFilter = nil
                        } else {
                            selectedTimeFilter = filter
                        }
                        selectedIndex = 0
                    }
                }

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)

                ForEach(recentSourceApps, id: \.self) { app in
                    QuickFilterChip(
                        title: app,
                        icon: "app.fill",
                        isSelected: selectedSourceApp == app
                    ) {
                        if selectedSourceApp == app {
                            selectedSourceApp = nil
                        } else {
                            selectedSourceApp = app
                        }
                        selectedIndex = 0
                    }
                }

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)

                ForEach([ClipboardItemType.code, .url, .text], id: \.self) { type in
                    QuickFilterChip(
                        title: type.displayName,
                        icon: type.icon,
                        isSelected: selectedContentType == type
                    ) {
                        if selectedContentType == type {
                            selectedContentType = nil
                        } else {
                            selectedContentType = type
                        }
                        selectedIndex = 0
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    TextField("Search clipboard history...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.body())
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            selectCurrentItem()
                        }

                    if !searchText.isEmpty || hasActiveFilters {
                        Button {
                            searchText = ""
                            selectedTimeFilter = nil
                            selectedSourceApp = nil
                            selectedContentType = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        onClose()
                    } label: {
                        Text("ESC")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DesignTokens.Colors.surfaceSecondary.opacity(0.5))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)

                if showFilters {
                    quickFilterBar
                }

                Divider()
                    .foregroundStyle(DesignTokens.Colors.borderSubtle)
            }
            .background(DesignTokens.Colors.glassPrimary)

            // Results list
            if filteredItems.isEmpty {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)

                    Text(searchText.isEmpty ? "No clipboard items" : "No results found")
                        .font(DesignTokens.Typography.body())
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DesignTokens.Spacing.xxl)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                FloatingSearchItemRow(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    index: index + 1,
                                    onTap: {
                                        selectedIndex = index
                                        selectCurrentItem()
                                    }
                                )
                                .id(index)

                                if index < filteredItems.count - 1 {
                                    Divider()
                                        .foregroundStyle(DesignTokens.Colors.borderSubtle.opacity(0.5))
                                        .padding(.horizontal, DesignTokens.Spacing.md)
                                }
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.sm)
                    }
                    .frame(maxHeight: 400)
                    .onChange(of: selectedIndex) { newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 600)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            isSearchFieldFocused = true
        }
        .onExitCommand {
            onClose()
        }
        .onMoveCommand { direction in
            handleArrowKey(direction)
        }
    }

    private func handleArrowKey(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
        case .down:
            if selectedIndex < filteredItems.count - 1 {
                selectedIndex += 1
            }
        default:
            break
        }
    }

    private func selectCurrentItem() {
        guard !filteredItems.isEmpty else { return }
        let item = filteredItems[selectedIndex]
        onItemSelected(item)
        onClose()
    }
}

/// Row view for floating search results
private struct FloatingSearchItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let index: Int
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Quick select number
            if index <= 9 {
                Text("⌘\(index)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .frame(width: 28)
            } else {
                Spacer()
                    .frame(width: 28)
            }

            // Content type badge
            ContentTypeBadge(type: item.type, size: .small)

            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                Text(item.firstLine)
                    .font(DesignTokens.Typography.body())
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 4) {
                    AppIconView(bundleIdentifier: item.sourceBundleIdentifier, appName: item.sourceApp, size: 12)

                    Text(item.sourceApp)
                        .font(DesignTokens.Typography.caption())
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    Text("•")
                        .font(DesignTokens.Typography.caption())
                        .foregroundStyle(DesignTokens.Colors.textTertiary)

                    TimestampLabel(item.timestamp)
                }
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.accentPrimary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            isSelected
                ? DesignTokens.Colors.accentPrimary.opacity(0.1)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

enum QuickTimeFilter: String, CaseIterable {
    case today
    case yesterday
    case thisWeek
    case morning
    case afternoon
    case evening

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }

    var icon: String {
        switch self {
        case .today: return "calendar"
        case .yesterday: return "calendar.badge.minus"
        case .thisWeek: return "calendar.badge.clock"
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }
}

private struct QuickFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.surfaceSecondary.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
}

class FloatingSearchWindowController: NSWindowController {
    private var hostingController: NSHostingController<AnyView>?

    init(clipboardStore: ClipboardStore,
         onClose: @escaping () -> Void,
         onItemSelected: @escaping (ClipboardItem) -> Void) {

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        // Configure panel
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        // Center window on screen
        window.center()

        // Create content view
        let contentView = FloatingSearchView(
            onClose: { [weak self] in
                self?.close()
                onClose()
            },
            onItemSelected: onItemSelected
        )
        .environmentObject(clipboardStore)

        // Set up hosting controller
        hostingController = NSHostingController(rootView: AnyView(contentView))
        window.contentViewController = hostingController

        // Animate in
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func close() {
        // Animate out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.window?.animator().alphaValue = 0
        }, completionHandler: {
            super.close()
        })
    }
}

/// Manager for floating search windows
class FloatingSearchManager: ObservableObject {
    static let shared = FloatingSearchManager()
    private var windowController: FloatingSearchWindowController?

    private init() {}

    func showFloatingSearch(clipboardStore: ClipboardStore) {
        // Close existing window if any
        hideFloatingSearch()

        // Create and show new window
        windowController = FloatingSearchWindowController(
            clipboardStore: clipboardStore,
            onClose: { [weak self] in
                self?.windowController = nil
            },
            onItemSelected: { item in
                // Copy item to clipboard
                clipboardStore.copyItemToClipboard(item)
            }
        )
    }

    func hideFloatingSearch() {
        windowController?.close()
        windowController = nil
    }
}