# ClipMind — Card-Shuffle Menu, New Logo, iPhone Capture

Date: 2026-06-18
Status: Approved design (pending final user review)

## Overview

Three independent improvements to ClipMind, bundled into one design pass:

1. **Card-shuffle menu** — replace the static vertical list in the menu-bar popover with an animated horizontal carousel of recent items (peeking stacked-card "deck", navigable by swipe/scroll/arrow-keys/drag).
2. **New logo** — a minimal "clipboard + teal dot" mark, replacing the current clipboard-stack logo, generated into the full app-icon set plus a monochrome menu-bar glyph.
3. **iPhone capture** — correctly detect and label clipboard items that arrive from an iPhone/iPad via macOS Universal Clipboard (today they are captured but mislabeled with the frontmost Mac app).

All frontend design decisions in this spec were grounded with the `ui-ux-pro-max` skill (micro-interactions style, spring physics, reduced-motion support).

## Goals & Non-Goals

**Goals**
- The popover feels tactile and modern; browsing recent items is one-card-at-a-time with a snappy spring.
- The new mark is recognizable at 512px (app icon) and legible at 18px (menu bar), in both light and dark menu bars.
- iPhone/iPad copies are labeled as such instead of attributed to whatever Mac app was frontmost.

**Non-Goals**
- No dedicated iOS companion app (explicitly deferred — see Feature C, "Rejected alternative").
- No change to the Dashboard, search, or detail views beyond what the model change requires.
- No change to capture latency targets or the polling architecture.

---

## Feature A — Card-Shuffle Menu Carousel

### Current state
`clipmind/Views/MenuBar/ClipboardMenuPopover.swift` renders `recentItems` as a static `VStack` of `ClipboardItemRow`s inside a 360pt-wide glass `NSPopover` (`MenuBarController.setupMenuBar`, `clipmind/Views/MenuBar/MenuBarView.swift:39`). `recentItems` is the first `maxRecentItems` (=5) items from the store (`clipmind/Services/ClipboardStore.swift:22,173`).

### Target UX (approved)
- The list area becomes a **horizontal deck**: the front card is sharp and centered; the neighbors are scaled (~0.88, 0.76), rotated (~±5°, ±10°), and dimmed (opacity ~0.5, ~0.24) behind it. Cards beyond ±2 are hidden.
- **Navigation**, all snapping exactly one card at a time:
  - Side chevron buttons (dimmed/disabled at the ends).
  - `←` / `→` arrow keys.
  - Trackpad scroll / two-finger swipe (wheel events; debounced ~320ms so one swipe = one card).
  - Drag the front card horizontally; release past a threshold advances, otherwise springs back.
- **Indicator**: a row of page dots (active dot elongates into a pill) plus a subtle `n / total` counter.
- **Tap the front card** → copy it to the clipboard, show the existing teal "Copied" toast + light haptic, then **close the popover** (quick-paste flow — approved). Right-click keeps the current context menu (Copy / Delete).
- The header, footer (Dashboard / Quit), refined empty state, and glass background are preserved.
- Show **8** recent items in the deck (bump `maxRecentItems` 5 → 8).

### Components
- **`CardCarousel`** (new, `clipmind/Views/MenuBar/CardCarousel.swift`): generic, reusable view.
  - Inputs: `items: [ClipboardItem]`, `currentIndex: Binding<Int>`, `onActivate: (ClipboardItem) -> Void`.
  - Owns the deck geometry (offset → transform mapping), gesture handling (`DragGesture`, scroll via an `NSEvent` scroll monitor or `onScroll`-style handler), keyboard handling (`.onKeyPress(.leftArrow/.rightArrow)` on macOS 14+, with a `KeyEventHandling` NSViewRepresentable fallback), and the snap animation using `DesignTokens.Animation.spring`.
  - Renders each card via a new **`CarouselCard`** subview.
- **`CarouselCard`** (new, same file or sibling): card chrome around the item — app icon (`AppIconView`), content preview (reuse `RichContentPreview` in compact mode or `truncatedPreview`), `ContentTypeBadge`, source-app + timestamp row, and the device badge when the item is from Universal Clipboard (Feature C).
- **`CarouselIndicator`** (new): dots + counter.
- `ClipboardMenuPopover` swaps its `itemsList` body for `CardCarousel`; keeps `header`, `footer`, `emptyState`.

### Animation & accessibility
- Transforms animate `transform`/`opacity` only, ~0.36s spring for position, ~0.26s for opacity (matches ui-ux guidance: spring physics, 150–400ms, exit faster than enter).
- `@Environment(\.accessibilityReduceMotion)`: when true, replace the shuffle with a simple crossfade and no rotation/scale.
- Each card is a focusable, labeled control (`accessibilityLabel` = type + preview + source); chevrons have labels; the deck supports full keyboard nav. Tap target ≥44pt.
- Drag has a movement threshold (~10pt) before it starts, to avoid hijacking taps (`drag-threshold`).

### Data
- `ClipboardStore.maxRecentItems` 5 → 8 (`clipmind/Services/ClipboardStore.swift:22`). `updateRecentItems()` already slices `items.prefix(maxRecentItems)`, so no other store change.
- `currentIndex` resets to 0 when a new item arrives (the newest becomes the front card).

### Files touched
- New: `clipmind/Views/MenuBar/CardCarousel.swift` (CardCarousel + CarouselCard + CarouselIndicator).
- Edit: `clipmind/Views/MenuBar/ClipboardMenuPopover.swift` (use carousel; tap-to-copy now also closes — add `onActivate` that calls the store + `closePopover`).
- Edit: `clipmind/Views/MenuBar/MenuBarView.swift` (wire a close callback into the popover content; popover height may grow slightly to fit the deck — set `contentSize` height ~ 320–360).
- Edit: `clipmind/Services/ClipboardStore.swift` (maxRecentItems).

---

## Feature B — New Logo (minimal clipboard + dot)

### Decision
Final mark (approved): a **minimal clipboard silhouette** — a rounded board outline + a filled clip tab in warm orange `#F97316`, with a single teal dot `#14B8A6` as the "mind" — on a **light off-white squircle tile** (`#FAFAF9`). Palette unchanged from current brand.

### Master SVG (source of truth)
Author `clipmind/Resources/Logo.svg` (replacing the current clipboard-stack art) as a 512×512 mark. Reference geometry (implementation may fine-tune for optical balance):

```
viewBox 0 0 512 512
tile:      rect 0,0 512x512 rx=114 fill #FAFAF9
clip tab:  rect x=200 y=120 w=112 h=64  rx=28 fill #F97316
board:     rect x=156 y=156 w=200 h=236 rx=40 fill none stroke #F97316 stroke-width=30 (round joins)
mind dot:  circle cx=256 cy=290 r=30 fill #14B8A6
```

A second **monochrome master** (`clipmind/Resources/LogoGlyph.svg`) is the same board + clip tab + dot as a single-color silhouette (no tile), for the menu-bar template image.

### Asset pipeline
Generate PNGs from the masters with `rsvg-convert` (available; `cairosvg`/`magick` are fallbacks). A helper script `scripts/render-logo.sh` (new) renders:
- **App icon** → `clipmind/Assets.xcassets/AppIcon.appiconset/` at the 10 existing slots: 16/32/128/256/512 @1x and @2x (16, 32, 32, 64, 128, 256, 256, 512, 512, 1024 px).
- **Logo imageset** → `clipmind/Assets.xcassets/Logo.imageset/` `logo.png` (1x), `logo@2x.png`, `logo@3x.png` — used by `AppLogo` / in-app header. Base size ~128pt → 128/256/384 px.
- **Menu-bar glyph** → new `clipmind/Assets.xcassets/MenuBarGlyph.imageset/` rendered from `LogoGlyph.svg` as a template (monochrome) at 18/36/54 px, with `Contents.json` `"template-rendering-intent":"template"`.

### Menu-bar usage
`MenuBarController.setupMenuBar` / `updateIcon` (`clipmind/Views/MenuBar/MenuBarView.swift:26,82`) currently load `NSImage(named: "Logo")` with `isTemplate = false`. Change to load `MenuBarGlyph` with `isTemplate = true` so it adapts to light/dark menu bars and matches macOS conventions. In-app usages of `AppLogo` (`clipmind/DesignSystem/Components/AppLogo.swift`) keep using the colored `Logo` asset — no API change to `AppLogo`.

### Files touched
- New: `clipmind/Resources/Logo.svg` (replace), `clipmind/Resources/LogoGlyph.svg`, `scripts/render-logo.sh`.
- New: `clipmind/Assets.xcassets/MenuBarGlyph.imageset/` (+ `Contents.json`).
- Regenerated PNGs: `AppIcon.appiconset/*`, `Logo.imageset/*`.
- Edit: `clipmind/Views/MenuBar/MenuBarView.swift` (template menu-bar glyph).

---

## Feature C — iPhone Capture via Universal Clipboard

### Finding (research-backed)
macOS already delivers iPhone/iPad copies onto `NSPasteboard.general` via Universal Clipboard, and ClipMind's polling **already captures them** — it just mislabels them with the frontmost Mac app (`ClipboardMonitor.handleClipboardChange`, `clipmind/Services/ClipboardMonitor.swift:112`, attributes via `MetadataExtractor.extractExtendedMetadata`). The fix is detection + correct labeling. Device *name* and *type* are not exposed to apps, so the label is generic ("iPhone / iPad").

### Detection
Add a pasteboard type constant and check it before attribution:
```swift
extension NSPasteboard.PasteboardType {
    static let universalClipboard = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
}
```
In `handleClipboardChange()`, compute `let isRemote = pasteboard.types?.contains(.universalClipboard) ?? false` (pasteboard-level check is most robust per Maccy's note that `types` returns all available types).

- When `isRemote` is true: **skip frontmost-app attribution** (do not call the AX/window-title path for it), set the item's origin to the remote device, and do **not** apply the `metadata.bundleIdentifier == appBundleIdentifier` self-ignore (a remote item is never our own copy).
- When false: behavior unchanged.

### Labeling / model change
Add an explicit origin so the UI can badge and the dashboard can filter:
- `ClipboardItem` (`clipmind/Models/ClipboardItem.swift`): add `var origin: ClipboardOrigin = .local` (Codable, defaulted → backward-compatible decode).
- New enum `ClipboardOrigin: String, Codable { case local, universalClipboard }` with display helpers (`displayName` = "This Mac" / "iPhone / iPad", `iconSystemName` = nil / "iphone").
- For remote items, set `sourceApp = "iPhone / iPad"`, `sourceBundleIdentifier = nil`, `windowTitle = nil`, `origin = .universalClipboard`.

**Persistence (SQLite, column-based — `clipmind/Services/DatabaseService.swift`)**:
- Migration: `ALTER TABLE clipboard_items ADD COLUMN origin TEXT NOT NULL DEFAULT 'local';` guarded so it runs once (check `PRAGMA table_info` or catch the duplicate-column error).
- Update the insert statement (`DatabaseService.swift:241`) and all `SELECT … source_app …` reads (lines ~335, 413, 456, 543, 780–821, 863, 891, 919, 947) to include and hydrate `origin`. Default missing/legacy rows to `.local`.

### UI
- `CarouselCard` (Feature A) and `ClipboardItemRow` show a small device badge ("iPhone / iPad" with `iphone` SF Symbol) when `item.origin == .universalClipboard` (this is the 3rd card in the approved mockup).
- `AppIconView` (`clipmind/DesignSystem/Components/AppIconView.swift`): when `origin` is remote (passed via a new optional param or detected from a sentinel), render an `iphone` SF Symbol instead of attempting bundle-id icon resolution. Minimal approach: pass `origin` into the icon view; fall back to current behavior otherwise.

### macOS privacy forward-compat (important)
macOS 15.4+ / macOS 26 ("Tahoe") add pasteboard-privacy prompts for background clipboard readers, plus new non-reading *detect* APIs and `NSPasteboard.accessBehavior`.
- Gate the remote-marker check to use the new **detect APIs** when available (`if #available`), since they inspect *types* without reading content and won't trip the read alert; fall back to `pasteboard.types` on older OSes.
- Adopt `NSPasteboard.accessBehavior` where available. Surface a settings affordance / first-run note if the OS shows the "Paste from Other Apps" permission. (Implementation detail; can be staged.)

### Rejected alternative
A dedicated iOS companion app (to capture every iPhone copy regardless of Handoff) was considered and rejected for now: iOS forbids background clipboard polling, shows paste banners (iOS 14+) and a paste-permission prompt (iOS 16+), and would require a sync backend (CloudKit/Cloudflare). The Universal Clipboard path is ~10 lines and covers the common case. The `ClipboardOrigin` enum leaves room to add device kinds later without rework.

### Files touched
- Edit: `clipmind/Services/ClipboardMonitor.swift` (marker constant, `isRemote` branch in `handleClipboardChange`, skip remote attribution + self-ignore).
- Edit: `clipmind/Models/ClipboardItem.swift` (`origin` field, `ClipboardOrigin` enum, sample remote item).
- Edit: `clipmind/Services/DatabaseService.swift` (migration, insert + select for `origin`).
- Edit: `clipmind/DesignSystem/Components/AppIconView.swift` (device glyph for remote origin).
- Edit: `clipmind/Views/MenuBar/ClipboardItemRow.swift` (+ `CarouselCard`) device badge.

---

## Cross-Cutting

### Error handling
- Carousel: clamp `currentIndex` to `0..<items.count`; guard empty deck (show existing empty state); ignore gestures while `items.isEmpty`.
- Logo pipeline: `render-logo.sh` fails loudly if no rasterizer is found; verifies each output exists and is non-zero.
- Universal Clipboard: never eagerly read large remote payloads just to classify — check `types` first; reading content stays on the existing path. Treat a missing marker as `.local` (fail safe).
- DB migration wrapped so a re-run or pre-existing column does not crash startup.

### Testing
- Reuse existing tests; add where present (check for an existing test target first per workflow rules).
- Unit: `ClipboardOrigin` round-trips Codable; `ClipboardItem` decodes legacy JSON without `origin` → `.local`; DB insert/select preserves `origin`; carousel index clamping.
- Manual: copy on iPhone (same iCloud, Handoff on) → item appears labeled "iPhone / iPad" with device badge; verify carousel nav via all four input methods; verify reduced-motion crossfade; verify menu-bar glyph in light and dark menu bars; verify app icon at 16px and 512px.
- Build gate: `xcodebuild -scheme clipmind -configuration Debug build` clean before commit (per project + global build rules).

### Sequencing (independent, can land separately)
1. Logo (self-contained assets + menu-bar swap).
2. iPhone capture (model + monitor + DB migration).
3. Carousel (consumes the device badge from #2, but degrades fine without it).
