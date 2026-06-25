# ClipMind Phase 2 — Timeline Dashboard + Notch HUD — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Steps use checkbox (`- [ ]`).

**Goal:** Replace the sidebar/List-Grid-Compact dashboard with a lean, day-grouped timeline (debounced search; date/time/type/source-app/device filters), and add a notch capture HUD on copy.

**Architecture:** Lower-risk transformation — keep the existing `searchDatabase` path for query + type + date-range + workspace, and layer device/source-app/time-of-day as in-memory filters + day-grouping + a new lean row. The notch HUD is a borderless `NSPanel` driven by the existing capture event.

**Tech Stack:** SwiftUI / AppKit, macOS 13+ (guard 14-only APIs), existing `DatabaseService`/`SearchService`/`ClipboardStore`.

**Spec:** `docs/superpowers/specs/2026-06-18-dashboard-redesign-notch-hud-design.md`

## Global Constraints
- macOS 13+; no inline comments; strict types; build clean before each commit (`xcodebuild -scheme clipmind -configuration Debug build CODE_SIGNING_ALLOWED=NO`).
- Reuse `DesignTokens`, `ContentTypeBadge`, `AppIconView`, `TimestampLabel`, `GlassCard`, `ToastView`.
- Device filter uses Phase 1 `ClipboardItem.origin`. Brand palette warm `#F97316`/teal `#14B8A6`.
- Notch HUD: on by default, toggleable; skip sensitive items; throttle rapid copies.

## Known current state (from reading the code)
- `DashboardView` (1089 ln): `NavigationSplitView` + sidebar + `viewMode` (List/Grid/Compact); `filteredItems` switches store.items vs `searchResults`; `performSearch()` → `clipboardStore.searchDatabase(query:filter:options:)`; no debounce; filters: `selectedFilter` (type), `selectedWorkspace`, `selectedDateRange` (presets), `showSensitiveOnly`, `sortOption`.
- `SearchFilter` fields: `query, types, workspaceIds, dateRange, isSensitiveOnly` (no source-app/origin/time-of-day).
- `AdvancedDateFilter` (unused): `TimeOfDay` (timeRange hours), custom range, `matches(date:)`.
- `MenuBarExtra` is the live menu path (fixed in Phase 1).

---

## Feature D — Timeline Dashboard

### File structure
- New: `clipmind/Views/Dashboard/TimelineItemRow.swift` (lean single-line row, hover actions, device badge).
- New: `clipmind/Views/Dashboard/DashboardModels.swift` (`DaySection` + `groupByDay` + `TimeOfDay` reuse).
- Modify: `clipmind/Views/Dashboard/DashboardView.swift` (replace layout; add filters; debounce).

### Task D1: Day-grouping + lean row (new files)
- [ ] Create `DashboardModels.swift`: `struct DaySection: Identifiable { let id: String; let title: String; let items: [ClipboardItem] }` and `func groupByDay(_ items: [ClipboardItem]) -> [DaySection]` bucketing into Today / Yesterday / This Week / Earlier (preserve descending order; drop empty buckets).
- [ ] Create `TimelineItemRow.swift`: leading type glyph (`item.type.icon`/`color`), single-line `truncatedPreview(maxLength:120)`, sub-line `sourceApp · TimestampLabel` + iPhone badge when `origin == .universalClipboard`; trailing hover-revealed buttons Copy + Delete; whole row `onTap` → detail. Reuse `ContentTypeBadge` styling tokens; respect `accessibilityReduceMotion`.
- [ ] Build → BUILD SUCCEEDED. Commit `feat: timeline day-grouping and lean dashboard row`.

### Task D2: Replace dashboard layout with the timeline
- [ ] In `DashboardView`, add state: `originFilter: ClipboardOrigin?`, `sourceAppFilter: String?`, `timeOfDay: TimeOfDay?`, `customRange: DateRange?`.
- [ ] Add `displayItems`: `filteredItems` further filtered by `originFilter`, `sourceAppFilter`, and `timeOfDay` (hour-of-day via `Calendar`). Add `sections: [DaySection] = groupByDay(displayItems)`.
- [ ] Replace `body` `NavigationSplitView` with a single-column `VStack`: `dashboardHeader` (new logo via `AppLogo`, "ClipMind", `totalItemCount`, workspace `Menu`, settings/shortcuts buttons) → `searchField` → `filterBar` → timeline `ScrollView`(`LazyVStack` of `TimelineSection` headers + `TimelineItemRow`s) with the existing pagination footer; keep `emptyState` (improved "no matches" copy), `loadingOverlay`, `multiPasteBanner`, all `.sheet`s, `.alert`, `.toast`.
- [ ] Remove `sidebar`, `workspacesSection`, `viewMode` toolbar, `listView/gridView/compactView`, `filtersPanel/activeFiltersBar/dateRangeChip`. Keep `FilterButton`/`WorkspaceFilterButton` only if still referenced (else delete).
- [ ] Build → SUCCEEDED. Commit `feat: lean day-grouped timeline dashboard layout`.

### Task D3: Filter bar (When / Type / Device / Source app) + debounce
- [ ] Build `filterBar`: chip groups — When (All/Today/Yesterday/This Week + Custom range popover + TimeOfDay chips), Type (All + `ClipboardItemType.allCases`), Device (All/Mac/iPhone → `originFilter`), Source app (`Menu` listing distinct `clipboardStore.items.map(\.sourceApp)` → `sourceAppFilter`). Active chips use accent fill; a Clear control resets all.
- [ ] Wire `When` presets/custom to `selectedDateRange` (DB) and `timeOfDay` (in-memory); add `.onChange` for the new filters → `performSearch()`/recompute.
- [ ] Add debounce to `performSearch()`: `try? await Task.sleep(nanoseconds: 250_000_000)` before the DB call, guarded by `Task.isCancelled`.
- [ ] Build → SUCCEEDED. Commit `feat: dashboard filter bar with date/time, type, device, source-app + debounced search`.

---

## Feature E — Notch Capture HUD

### File structure
- New: `clipmind/Services/NotchHUDController.swift` (ObservableObject + NSPanel lifecycle, throttle, sensitive-skip).
- New: `clipmind/Views/Notch/NotchHUDView.swift` (SwiftUI content: logo + "Saved" + mini preview + hover actions).
- Modify: `clipmind/clipmindApp.swift` (instantiate controller; present on capture), `clipmind/Services/ClipboardStore.swift` (expose a capture callback/published latest item), `clipmind/Views/Settings/SettingsView.swift` (enable toggle).

### Task E1: NotchHUDView + Controller
- [ ] Create `NotchHUDView.swift`: a rounded-bottom black panel (notch-hug) showing `AppLogo`(small) + "Saved to ClipMind" + a row with type glyph + one-line preview + `sourceApp · TimestampLabel` + iPhone badge; on hover reveal Pin(stub)/Copy/Open buttons; reduced-motion → fade not spring. Never preview content when `item.isMarkedSensitive`.
- [ ] Create `NotchHUDController.swift`: owns a borderless `NSPanel` (`[.borderless, .nonactivatingPanel]`, `level = .statusBar`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, `isFloatingPanel = true`, clear bg), hosts `NotchHUDView` via `NSHostingView`. `present(item:)` positions it centered at top of `NSScreen.main` (use `safeAreaInsets.top` to size under the notch; pill fallback otherwise), animates in, arms a ~2.5s dismiss timer, and **coalesces** (replaces content if a new item arrives while shown). Skip when disabled or `item.isMarkedSensitive`.
- [ ] Build → SUCCEEDED. Commit `feat: notch capture HUD view and panel controller`.

### Task E2: Hook capture + settings toggle
- [ ] In `ClipboardStore`, expose the just-captured item (e.g. `@Published private(set) var lastCaptured: ClipboardItem?` set in the add path, or a callback) without disturbing existing flow.
- [ ] In `clipmindApp`, create `@StateObject NotchHUDController`; on `clipboardStore.lastCaptured` change (and `@AppStorage("notchHUDEnabled")` true), call `present(item:)`.
- [ ] In `SettingsView`, add a `Toggle("Show capture notification near the notch", isOn: @AppStorage("notchHUDEnabled"))` (default true).
- [ ] Build → SUCCEEDED. Commit `feat: show notch HUD on capture with settings toggle`.

---

## Cross-Cutting
- Error handling: empty/zero-result timeline → descriptive empty state; clamp pagination; notch no-ops if no screen/disabled/sensitive; never block capture on HUD failure.
- Verification: clean Debug build per task; manual run for timeline filtering, day grouping, debounce, notch on notch/non-notch Macs, sensitive-skip, settings toggle.
- Open follow-ups (not blocking): true paged filtered queries for very large histories; `isPinned` for the HUD Pin action (stubbed now); retire `ClipboardGridItemView`/`ClipboardCompactItemView` once confirmed unreferenced.

## Self-Review
- Spec coverage: timeline layout ✓D2, date/time+type+device+source filters ✓D3, debounce ✓D3, lean row + day grouping ✓D1, notch HUD mini-preview+actions+smart triggers ✓E1-E2, settings toggle ✓E2. Workspace filtering demoted to header menu ✓D2.
- Placeholder scan: UI code authored during execution against the real files (as in Phase 1); logic (grouping, throttle, time-of-day) is concrete.
- Type consistency: `DaySection`/`groupByDay`, `originFilter`/`sourceAppFilter`/`timeOfDay`, `present(item:)`, `notchHUDEnabled`, `lastCaptured` used consistently.
