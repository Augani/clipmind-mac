# ClipMind Phase 2 — Dashboard Redesign + Notch Capture HUD

Date: 2026-06-18
Status: Approved design (pending final user review)
Builds on: `2026-06-18-menu-carousel-logo-iphone-capture-design.md` (Phase 1)

## Overview

Two Phase-2 improvements, to be built after Phase 1:

1. **Dashboard redesign** — replace the current sidebar + List/Grid/Compact dashboard with a lean, search-first **timeline** (items grouped by day), with fast date/time + type + source-app + device filtering and tasteful animation.
2. **Notch capture HUD** — when ClipMind captures a copy, drop a small confirmation panel from the MacBook camera notch (top-center pill on non-notch Macs) showing a mini preview + quick actions.

All UI grounded with the `ui-ux-pro-max` skill (micro-interactions, spring physics, debounced search, reduced-motion, "no results" states).

## Dependencies on Phase 1
- Uses the `ClipboardItem.origin` field (Mac vs iPhone/iPad) for the **Device** filter and the row/HUD device badge.
- Uses the new logo glyph in the dashboard header and HUD.
- Shares a single lean item-row component introduced here (also reconciles Phase 1's `ClipboardItemRow`).

## Goals & Non-Goals
**Goals**
- Find a past copy fast: prominent search, day-grouped timeline, one scannable row style.
- "Date / time / both" filtering with quick presets + custom range + time-of-day.
- A capture HUD that confirms "we have it" without stealing focus, smart enough not to spam.

**Non-Goals**
- No new sync/backend. No multi-window routing changes beyond opening the existing dashboard window.
- Not redesigning Settings, Onboarding, or Workspace editors (workspace *filtering* is demoted to a small menu, not removed).

---

## Feature D — Dashboard Redesign (timeline)

### Current state (from code map)
- `clipmind/clipmindApp.swift` (123 ln): menu-bar app (`.accessory`); dashboard is a `WindowGroup` id `"main-dashboard"`, `.hiddenTitleBar`, default 900×700; opened via `openWindow` + a fragile `WindowManager.openMainWindow()` (string/title matching + timed fallback, lines 80-101).
- `clipmind/Views/Dashboard/DashboardView.swift` (**1089 ln**): `NavigationSplitView` with a sidebar (workspaces + type filters) and a toolbar (`ViewMode` List/Grid/Compact + Sort menu + multi-select). Flat, **ungrouped** lists per mode; three divergent row components (`ClipboardItemRow` 173 ln, `ClipboardGridItemView` 186 ln, `ClipboardCompactItemView` 128 ln). Detail via `.sheet(item:)` → `ClipboardItemDetailView` (278 ln).
- Search: inline `searchBar`; every keystroke triggers `performSearch()` → `clipboardStore.searchDatabase(...)` → `SearchService` re-rank. **No debounce** (only task cancellation).
- Filters: scattered local `@State`/`@AppStorage` (`selectedFilter`, `selectedWorkspace`, `selectedDateRange` [Today/Yesterday/LastWeek/LastMonth only], `showSensitiveOnly`, `sortOption`) with 7 `.onChange` re-searches. **No source-app filter UI.** `SortOption.contentLength` wrongly maps to `.relevance`.
- **Orphaned capability**: `clipmind/Views/Search/AdvancedDateFilterView.swift` (133 ln) defines `AdvancedDateFilter` (TimeOfDay, DayOfWeekPattern, RelativeTime, custom range, `matches(date:)`) — **unused by any filter UI**. We adopt it.
- `filteredItems` silently switches between paginated `items` and capped (`maxResults` 500) `searchResults` — filtered results aren't paginated.

### Target UX (approved: timeline, all-in lean)
- **Header**: new logo + title; a prominent **search field** (debounced ~250ms, `esc` to clear) with a "No matches — try …" empty state.
- **Filter bar** (chips, directly under search):
  - **When**: All / Today / Yesterday / This week + **Custom** (date range) + **time-of-day** (Morning/Afternoon/Evening/Night or an hour window) — backed by `AdvancedDateFilter`.
  - **Type**: All / Text / Link / Code / Image / File.
  - **Device**: All / Mac / iPhone (from `origin`).
  - **Source app**: a searchable popover listing apps seen in history (new; today only sort-by-app exists).
  - Active filters summarized as removable chips; one "Clear" affordance.
- **Timeline**: a single `ScrollView` + `LazyVStack`, items grouped into **sections by day** (Today / Yesterday / This week / earlier dates), each with a section header + count. **One lean row** (`TimelineItemRow`): type glyph, single-line preview, source app · time, iPhone badge when remote; hover reveals quick actions (Pin / Copy / Delete); click copies (toast), double-click or a row affordance opens the detail sheet (reused `ClipboardItemDetailView`).
- **Animation**: rows stagger-in (~30–40ms) on filter/search change; section reflow animates; `accessibilityReduceMotion` → instant. Uses `DesignTokens.Animation`.
- **View modes**: dropped (Grid/Compact + sidebar removed). Workspaces reachable via a small menu/filter in the header, not a sidebar.

### Architecture (decompose the 1089-line view)
- **`DashboardFilterModel`** (new, `ObservableObject`): single source of truth for `query`, `advancedDate: AdvancedDateFilter?`, `type: ClipboardItemType?`, `origin: ClipboardOrigin?`, `sourceApp: String?`, `sort`. Publishes a derived `SearchFilter` + `SearchOptions`. One debounced pipeline replaces the 7 scattered `.onChange` searches (fixes that tech debt). Exposes grouped results (`[DaySection]`).
- **`DashboardView`** (slimmed): composes header + filter bar + timeline + overlays; owns the filter model.
- **`DashboardSearchHeader`** (new): logo + search field + workspace menu.
- **`DashboardFilterBar`** (new): the chip groups + custom date/time popover (`DateTimeFilterPopover`, wrapping `AdvancedDateFilter`).
- **`TimelineList`** + **`TimelineSection`** (new): day grouping + lazy rows + pagination footer.
- **`TimelineItemRow`** (new): the single lean row, replacing the three divergent components (Grid/Compact removed; Phase 1's `ClipboardItemRow` either becomes this or is kept only for the menu carousel — see Open Questions).
- Move `FilterButton`/`WorkspaceFilterButton` out of `DashboardView` into their own files (or delete if unused after redesign).

### Data / correctness
- Group + paginate the **filtered** path too (don't silently cap at 500): page DB results by day. Add real debounce in `DashboardFilterModel`.
- Fix `SortOption.contentLength` → a real content-length sort (or remove the option).
- Source-app list derived from `DatabaseService` (there is already a `SELECT source_app, COUNT(*) … GROUP BY source_app` at `DatabaseService.swift:975`).

### Accessibility
- Search field labeled; chips are toggle buttons with selected state announced; rows are labeled buttons (type + preview + source + device); full keyboard nav; reduced-motion honored; ≥44pt targets; "no results" is descriptive.

### Files touched
- New: `clipmind/Views/Dashboard/DashboardFilterModel.swift`, `DashboardSearchHeader.swift`, `DashboardFilterBar.swift`, `DateTimeFilterPopover.swift`, `TimelineList.swift`, `TimelineSection.swift`, `TimelineItemRow.swift`.
- Edit (shrink): `clipmind/Views/Dashboard/DashboardView.swift` (compose new pieces; remove sidebar + view-mode toolbar + scattered filter state).
- Adopt: `clipmind/Views/Search/AdvancedDateFilterView.swift` (wire `AdvancedDateFilter` into `DateTimeFilterPopover`; convert `matches(date:)` into a DB-backed range where possible).
- Edit: `clipmind/Services/ClipboardStore.swift` / `DatabaseService.swift` (grouped + paginated filtered queries; source-app list; drop dead legacy search paths `searchWithService`/`searchInItems` if unused after redesign).
- Remove/retire: `ClipboardGridItemView`, `ClipboardCompactItemView` (Grid/Compact dropped) — verify no other references first.
- Reuse: `GlassCard`, `ContentTypeBadge`, `Buttons`, `Typography`, `ToastView`, `AppIconView`, `TimestampLabel`, `DesignTokens`.

---

## Feature E — Notch Capture HUD

### Behavior (approved)
- On a new capture, a panel **drops from the notch** showing: new logo + "Saved to ClipMind" + mini preview (type glyph + one-line snippet + source app · time + iPhone badge if remote).
- **Hover** keeps it open and expands a quick-actions row: **Pin**, **Copy again**, **Open** (dashboard). Leaving re-arms dismissal.
- **Auto-dismiss** after ~2.5s. Spring drop-in; reduced-motion → fade.
- **Smart triggers** (approved "every copy, but smart"): skip items flagged sensitive (`ClipboardItem.isMarkedSensitive` / `SecurityService`); **throttle/coalesce** rapid copies (a new capture within the dismiss window replaces the current HUD content instead of stacking).
- **Settings**: `@AppStorage("notchHUDEnabled")` default **true**; optional auto-dismiss-duration. Lives in `SettingsView`.

### Positioning & window
- **Notch detection**: `NSScreen.safeAreaInsets.top > 0` (macOS 12+) indicates a notch; size/center the HUD to emerge from under it using `NSScreen.main` frame and `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`. Non-notch screens → render as a rounded **top-center pill** just under the menu bar.
- **Panel**: a borderless **`NSPanel`** (`styleMask: [.borderless, .nonactivatingPanel]`), `level = .statusBar` (above the menu bar), `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`, `isFloatingPanel = true`, `hidesOnDeactivate = false`, clear background, ignores mouse except over its content. Content is a SwiftUI `NotchHUDView` via `NSHostingView`. Does **not** activate the app or steal focus.
- **Multi-display**: show on the screen with the active/menu-bar focus (`NSScreen.main`); reposition on screen-config change.

### Trigger plumbing
- **`NotchHUDController`** (new, `ObservableObject` + AppKit): owns the panel, show/replace/hide, and the dismiss timer.
- Hook the existing capture flow: `ClipboardMonitor.onNewClipboardItem` → `ClipboardStore` add path already runs on new items. The store (or `clipmindApp`) notifies `NotchHUDController.present(item:)`. Apply the smart filter (sensitive skip + throttle) in the controller.
- Actions: Pin → store pin/favorite (if present, else add a lightweight `isPinned`); Copy again → `clipboardStore.copyItemToClipboard`; Open → `WindowManager.openMainWindow()`.

### Accessibility / quality
- Respect reduced-motion (fade, no spring). The HUD is supplementary (never the only confirmation — the item is in history regardless). `aria`/accessibility labels on actions. Honor a sensitive item by not previewing its content.

### Files touched
- New: `clipmind/Services/NotchHUDController.swift`, `clipmind/Views/Notch/NotchHUDView.swift`, `clipmind/Views/Notch/NotchShape.swift` (notch-hugging rounded shape).
- Edit: `clipmind/clipmindApp.swift` (instantiate `NotchHUDController`; wire to capture + `WindowManager`).
- Edit: `clipmind/Services/ClipboardStore.swift` (emit "captured" event to the HUD controller; optional `isPinned`).
- Edit: `clipmind/Views/Settings/SettingsView.swift` (HUD enable toggle + duration).

---

## Cross-Cutting

### Error handling
- Dashboard: empty query + no filters → show recent timeline (paginated); zero results → descriptive empty state; clamp pagination; guard against the 500-cap truncation by paging.
- Notch: if no screen/`NSScreen.main`, no-op gracefully; never block capture if the HUD fails to present; skip presentation entirely when disabled or item is sensitive.

### Testing
- Check for an existing test target first (per workflow rules).
- Unit: `DashboardFilterModel` derives correct `SearchFilter` from chips; `AdvancedDateFilter.matches` for time-of-day/custom range; day-grouping logic; debounce coalesces keystrokes; source-app list.
- Unit: `NotchHUDController` throttle/coalesce; sensitive-skip; enabled-toggle gating.
- Manual: search + each filter combo; custom date + time-of-day; reduced-motion; notch Mac vs non-notch (pill); multi-display; rapid copies coalesce; sensitive copy shows no preview; Settings toggle off → no HUD.
- Build gate: `xcodebuild -scheme clipmind -configuration Debug build` clean before commit.

### Sequencing
1. Ship Phase 1 (logo, iPhone origin, carousel).
2. Dashboard redesign (Feature D) — consumes `origin` + lean row + new logo.
3. Notch HUD (Feature E) — consumes capture event + sensitive flag.

### Open questions (resolve in planning)
- Whether `TimelineItemRow` fully replaces Phase 1's `ClipboardItemRow`, or the menu carousel keeps its own card and only the dashboard adopts the new row. Leaning: one shared lean row, carousel card wraps it.
- Whether "Pin/favorite" already exists in the model; if not, add a minimal `isPinned` (small migration) or defer pinning.
