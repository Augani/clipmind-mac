# ClipMind Phase 1 — Logo, iPhone Capture, Card-Shuffle Menu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new clipboard logo, correctly label iPhone/iPad (Universal Clipboard) copies, and replace the menu-bar popover's static list with an animated card-shuffle carousel.

**Architecture:** Three independent, sequenced features. Logo is asset-only + a menu-bar wiring change. iPhone capture adds a `ClipboardOrigin` field (model + SQLite column + monitor detection + UI badge). The carousel is a new SwiftUI component swapped into the existing popover. Logic is unit-tested via the existing `clipmindTests` XCTest target; views are verified by a clean `xcodebuild` build.

**Tech Stack:** Swift 5.9+ / SwiftUI / AppKit, SQLite (sqlite3 C API via `DatabaseService`), XCTest, `rsvg-convert` for asset generation.

**Spec:** `docs/superpowers/specs/2026-06-18-menu-carousel-logo-iphone-capture-design.md`

## Global Constraints

- macOS 14+; SwiftUI; async/await over completion handlers; Result types where errors propagate.
- No inline comments; no docstrings except public-API; strict types, no `any`; guard-clause/fail-fast; null-safety.
- Brand palette: warm `#F97316`→`#EA580C`, teal `#14B8A6`. Light squircle icon tile `#FAFAF9`.
- Run `xcodebuild -scheme clipmind -configuration Debug build` clean (zero errors/warnings introduced) before every commit.
- Commit messages: `type: description` (feat/fix/refactor/docs/test). Frequent, focused commits.
- iPhone-origin label is generic ("iPhone / iPad") — macOS does not expose device name/type.
- New deck size: `maxRecentItems = 8`.

---

## Feature B — New Logo (do first; self-contained)

### File structure
- Create: `clipmind/Resources/Logo.svg` (replace existing), `clipmind/Resources/LogoGlyph.svg`, `scripts/render-logo.sh`.
- Create: `clipmind/Assets.xcassets/MenuBarGlyph.imageset/Contents.json` + PNGs.
- Regenerate: `clipmind/Assets.xcassets/AppIcon.appiconset/*.png`, `clipmind/Assets.xcassets/Logo.imageset/logo*.png`.
- Modify: `clipmind/Views/MenuBar/MenuBarView.swift` (template menu-bar glyph).

### Task 1: Author logo masters + render script

**Files:**
- Create: `clipmind/Resources/Logo.svg`, `clipmind/Resources/LogoGlyph.svg`, `scripts/render-logo.sh`

**Interfaces:**
- Produces: `scripts/render-logo.sh` renders all AppIcon, Logo.imageset, and MenuBarGlyph PNGs from the two SVG masters.

- [ ] **Step 1: Write `clipmind/Resources/Logo.svg`** (colored mark, light squircle)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <rect width="512" height="512" rx="114" fill="#FAFAF9"/>
  <rect x="200" y="120" width="112" height="64" rx="28" fill="#F97316"/>
  <rect x="156" y="156" width="200" height="236" rx="40" fill="none" stroke="#F97316" stroke-width="30" stroke-linejoin="round"/>
  <circle cx="256" cy="290" r="30" fill="#14B8A6"/>
</svg>
```

- [ ] **Step 2: Write `clipmind/Resources/LogoGlyph.svg`** (monochrome, no tile, for template menu-bar image — uses `#000` so the template renderer derives the mask)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <rect x="176" y="150" width="160" height="190" rx="34" fill="none" stroke="#000000" stroke-width="30" stroke-linejoin="round"/>
  <rect x="222" y="112" width="68" height="48" rx="20" fill="#000000"/>
  <circle cx="256" cy="252" r="22" fill="#000000"/>
</svg>
```

- [ ] **Step 3: Write `scripts/render-logo.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
RSVG=$(command -v rsvg-convert || true)
if [ -z "$RSVG" ]; then echo "ERROR: rsvg-convert not found (brew install librsvg)"; exit 1; fi
render() { "$RSVG" -w "$2" -h "$2" "$1" -o "$3"; [ -s "$3" ] || { echo "ERROR: empty $3"; exit 1; }; echo "  $3 (${2}px)"; }

ICON=clipmind/Assets.xcassets/AppIcon.appiconset
echo "App icon:"
render clipmind/Resources/Logo.svg 16   "$ICON/icon_16x16.png"
render clipmind/Resources/Logo.svg 32   "$ICON/icon_16x16@2x.png"
render clipmind/Resources/Logo.svg 32   "$ICON/icon_32x32.png"
render clipmind/Resources/Logo.svg 64   "$ICON/icon_32x32@2x.png"
render clipmind/Resources/Logo.svg 128  "$ICON/icon_128x128.png"
render clipmind/Resources/Logo.svg 256  "$ICON/icon_128x128@2x.png"
render clipmind/Resources/Logo.svg 256  "$ICON/icon_256x256.png"
render clipmind/Resources/Logo.svg 512  "$ICON/icon_256x256@2x.png"
render clipmind/Resources/Logo.svg 512  "$ICON/icon_512x512.png"
render clipmind/Resources/Logo.svg 1024 "$ICON/icon_512x512@2x.png"

LOGO=clipmind/Assets.xcassets/Logo.imageset
echo "Logo imageset:"
render clipmind/Resources/Logo.svg 128 "$LOGO/logo.png"
render clipmind/Resources/Logo.svg 256 "$LOGO/logo@2x.png"
render clipmind/Resources/Logo.svg 384 "$LOGO/logo@3x.png"

GLYPH=clipmind/Assets.xcassets/MenuBarGlyph.imageset
mkdir -p "$GLYPH"
echo "Menu-bar glyph:"
render clipmind/Resources/LogoGlyph.svg 18 "$GLYPH/glyph.png"
render clipmind/Resources/LogoGlyph.svg 36 "$GLYPH/glyph@2x.png"
render clipmind/Resources/LogoGlyph.svg 54 "$GLYPH/glyph@3x.png"
echo "Done."
```

- [ ] **Step 4: Create `clipmind/Assets.xcassets/MenuBarGlyph.imageset/Contents.json`**

```json
{
  "images" : [
    { "filename" : "glyph.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "glyph@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "glyph@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "template-rendering-intent" : "template" }
}
```

- [ ] **Step 5: Run the render script**

Run: `chmod +x scripts/render-logo.sh && ./scripts/render-logo.sh`
Expected: prints each generated PNG path; exits 0; all listed files exist and are non-empty.

- [ ] **Step 6: Verify the PNGs are valid**

Run: `file clipmind/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png clipmind/Assets.xcassets/MenuBarGlyph.imageset/glyph@2x.png`
Expected: both report `PNG image data`, with 1024×1024 and 36×36 dimensions respectively.

- [ ] **Step 7: Commit**

```bash
git add clipmind/Resources/Logo.svg clipmind/Resources/LogoGlyph.svg scripts/render-logo.sh clipmind/Assets.xcassets/AppIcon.appiconset clipmind/Assets.xcassets/Logo.imageset clipmind/Assets.xcassets/MenuBarGlyph.imageset
git commit -m "feat: new clipboard logo + template menu-bar glyph assets"
```

### Task 2: Use the template glyph in the menu bar

**Files:**
- Modify: `clipmind/Views/MenuBar/MenuBarView.swift` (`setupMenuBar` ~line 26-36, `updateIcon` ~line 82-90)

**Interfaces:**
- Consumes: `MenuBarGlyph` asset from Task 1.

- [ ] **Step 1: In `setupMenuBar`, load the template glyph**

Replace the `NSImage(named: "Logo")` block in `setupMenuBar` with:

```swift
if let glyph = NSImage(named: "MenuBarGlyph") {
    glyph.size = NSSize(width: 18, height: 18)
    glyph.isTemplate = true
    button.image = glyph
} else {
    button.image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "ClipMind")
}
```

- [ ] **Step 2: In `updateIcon`, mirror the same template glyph**

```swift
func updateIcon(itemCount: Int) {
    if let button = statusItem?.button, let glyph = NSImage(named: "MenuBarGlyph") {
        glyph.size = NSSize(width: 18, height: 18)
        glyph.isTemplate = true
        button.image = glyph
        button.toolTip = "ClipMind (\(itemCount) items)"
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add clipmind/Views/MenuBar/MenuBarView.swift
git commit -m "feat: use monochrome template glyph in menu bar"
```

> Visual check (manual, by the user): app icon in Finder/Dock and the menu-bar glyph in both light and dark menu bars.

---

## Feature C — iPhone Capture via Universal Clipboard

### File structure
- Modify: `clipmind/Models/ClipboardItem.swift` (add `ClipboardOrigin`, `origin` field).
- Modify: `clipmind/Services/DatabaseService.swift` (migration + bind/read `origin`).
- Modify: `clipmind/Services/ClipboardMonitor.swift` (detect marker, set origin/label).
- Modify: `clipmind/DesignSystem/Components/AppIconView.swift` (device glyph), `clipmind/Views/MenuBar/ClipboardItemRow.swift` (badge).
- Test: `clipmindTests/ClipboardOriginTests.swift` (new), extend `clipmindTests/DatabaseServiceTests.swift`.

### Task 3: `ClipboardOrigin` model + field (TDD)

**Files:**
- Modify: `clipmind/Models/ClipboardItem.swift`
- Test: `clipmindTests/ClipboardOriginTests.swift`

**Interfaces:**
- Produces: `enum ClipboardOrigin: String, Codable { case local, universalClipboard }` with `var displayName: String` and `var deviceSymbolName: String?`; `ClipboardItem.origin: ClipboardOrigin` (default `.local`).

- [ ] **Step 1: Write the failing test** — `clipmindTests/ClipboardOriginTests.swift`

```swift
import XCTest
@testable import clipmind

final class ClipboardOriginTests: XCTestCase {
    func testDisplayNameAndSymbol() {
        XCTAssertEqual(ClipboardOrigin.universalClipboard.displayName, "iPhone / iPad")
        XCTAssertEqual(ClipboardOrigin.universalClipboard.deviceSymbolName, "iphone")
        XCTAssertNil(ClipboardOrigin.local.deviceSymbolName)
    }

    func testLegacyItemDecodesToLocal() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","content":{"type":"text","value":"hi"},"type":"text","timestamp":0,"sourceApp":"Notes"}
        """.data(using: .utf8)!
        let item = try JSONDecoder().decode(ClipboardItem.self, from: legacy)
        XCTAssertEqual(item.origin, .local)
    }

    func testRemoteItemRoundTrips() throws {
        let item = ClipboardItem(content: .text("hi"), type: .text, sourceApp: "iPhone / iPad", origin: .universalClipboard)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded.origin, .universalClipboard)
    }
}
```

- [ ] **Step 2: Run, verify failure**

Run: `xcodebuild test -scheme clipmind -destination 'platform=macOS' -only-testing:clipmindTests/ClipboardOriginTests 2>&1 | tail -15`
Expected: compile failure (`ClipboardOrigin` undefined) or test failure.

- [ ] **Step 3: Add the enum + field** in `clipmind/Models/ClipboardItem.swift`

Add above `struct ClipboardItem`:

```swift
enum ClipboardOrigin: String, Codable {
    case local
    case universalClipboard

    var displayName: String {
        switch self {
        case .local: return "This Mac"
        case .universalClipboard: return "iPhone / iPad"
        }
    }

    var deviceSymbolName: String? {
        switch self {
        case .local: return nil
        case .universalClipboard: return "iphone"
        }
    }
}
```

In `ClipboardItem`, add the stored property (after `activityContext`) and an init parameter with default. Because the type uses a synthesized `Codable` with all-optional/defaulted fields, add `origin` to the property list and the memberwise init:

```swift
    var origin: ClipboardOrigin = .local
```

Add to `init(...)` signature: `origin: ClipboardOrigin = .local,` and body: `self.origin = origin`.

Add a decode fallback so legacy JSON without `origin` decodes (the struct uses synthesized Codable; a defaulted `var` already decodes as optional-with-default in Swift only if a custom init(from:) is present). Add an explicit `init(from decoder:)` is NOT required because `ClipboardContent` has custom coding but `ClipboardItem` is synthesized — to guarantee legacy decode, implement:

```swift
    enum CodingKeys: String, CodingKey {
        case id, content, type, timestamp, sourceApp, sourceBundleIdentifier, windowTitle, workspaceId, isMarkedSensitive, encryptedContent, sensitiveContentTypes, activityContext, origin
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        content = try c.decode(ClipboardContent.self, forKey: .content)
        type = try c.decode(ClipboardItemType.self, forKey: .type)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        sourceApp = try c.decode(String.self, forKey: .sourceApp)
        sourceBundleIdentifier = try c.decodeIfPresent(String.self, forKey: .sourceBundleIdentifier)
        windowTitle = try c.decodeIfPresent(String.self, forKey: .windowTitle)
        workspaceId = try c.decodeIfPresent(UUID.self, forKey: .workspaceId)
        isMarkedSensitive = try c.decodeIfPresent(Bool.self, forKey: .isMarkedSensitive) ?? false
        encryptedContent = try c.decodeIfPresent(Data.self, forKey: .encryptedContent)
        sensitiveContentTypes = try c.decodeIfPresent(Set<String>.self, forKey: .sensitiveContentTypes) ?? []
        activityContext = try c.decodeIfPresent(ActivityContext.self, forKey: .activityContext)
        origin = try c.decodeIfPresent(ClipboardOrigin.self, forKey: .origin) ?? .local
    }
```

(Keep the existing memberwise `init(...)`; add `origin` to it as above. Synthesized `encode(to:)` remains valid with the added `CodingKeys`.)

- [ ] **Step 4: Run, verify pass**

Run: `xcodebuild test -scheme clipmind -destination 'platform=macOS' -only-testing:clipmindTests/ClipboardOriginTests 2>&1 | tail -15`
Expected: all three tests PASS.

- [ ] **Step 5: Commit**

```bash
git add clipmind/Models/ClipboardItem.swift clipmindTests/ClipboardOriginTests.swift
git commit -m "feat: add ClipboardOrigin to model with legacy-safe decoding"
```

### Task 4: Persist `origin` (SQLite migration + bind/read) (TDD)

**Files:**
- Modify: `clipmind/Services/DatabaseService.swift` (schema/migration ~line 51; insert ~241-265; row hydration ~780-821)
- Test: `clipmindTests/DatabaseServiceTests.swift`

**Interfaces:**
- Consumes: `ClipboardItem.origin` (Task 3).
- Produces: `clipboard_items.origin TEXT NOT NULL DEFAULT 'local'`; insert/select preserve `origin`.

- [ ] **Step 1: Write the failing test** (append to `DatabaseServiceTests.swift`)

```swift
func testOriginPersistsAcrossSaveAndLoad() throws {
    let db = DatabaseService.shared
    let item = ClipboardItem(content: .text("from phone"), type: .text, sourceApp: "iPhone / iPad", origin: .universalClipboard)
    db.saveClipboardItem(item)
    let loaded = db.loadClipboardItems(limit: 50, offset: 0).first { $0.id == item.id }
    XCTAssertEqual(loaded?.origin, .universalClipboard)
}
```

(Use the same save/load method names this test file already uses; adjust to the real `DatabaseService` API if they differ.)

- [ ] **Step 2: Run, verify failure**

Run: `xcodebuild test -scheme clipmind -destination 'platform=macOS' -only-testing:clipmindTests/DatabaseServiceTests/testOriginPersistsAcrossSaveAndLoad 2>&1 | tail -15`
Expected: FAIL (origin not persisted → defaults to `.local`).

- [ ] **Step 3: Add the migration** after the `CREATE TABLE clipboard_items` block in `DatabaseService.swift` (idempotent — ignore "duplicate column"):

```swift
private func migrateAddOriginColumn() {
    let sql = "ALTER TABLE clipboard_items ADD COLUMN origin TEXT NOT NULL DEFAULT 'local';"
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
        sqlite3_step(stmt)
    }
    sqlite3_finalize(stmt)
}
```

Call `migrateAddOriginColumn()` right after table creation in the DB-setup path.

- [ ] **Step 4: Add `origin` to insert + select**

In the INSERT column list (line ~241) append `, origin`; add a matching `?` placeholder; bind it after the existing binds:

```swift
sqlite3_bind_text(statement, <nextIndex>, (item.origin.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
```

In each `SELECT ... source_app, ...` that hydrates items, add `origin` to the column list and read it in the row builder (near line ~780-821):

```swift
let originRaw = sqlite3_column_text(statement, <originColumnIndex>).map { String(cString: $0) } ?? "local"
let origin = ClipboardOrigin(rawValue: originRaw) ?? .local
```

Pass `origin: origin` into the `ClipboardItem(...)` constructor in the row builder.

- [ ] **Step 5: Run, verify pass**

Run: `xcodebuild test -scheme clipmind -destination 'platform=macOS' -only-testing:clipmindTests/DatabaseServiceTests 2>&1 | tail -15`
Expected: all DatabaseService tests PASS (including legacy rows defaulting to `.local`).

- [ ] **Step 6: Commit**

```bash
git add clipmind/Services/DatabaseService.swift clipmindTests/DatabaseServiceTests.swift
git commit -m "feat: persist clipboard item origin with idempotent migration"
```

### Task 5: Detect Universal Clipboard in the monitor (TDD on the pure check)

**Files:**
- Modify: `clipmind/Services/ClipboardMonitor.swift` (add type constant; `handleClipboardChange` ~112-138)
- Test: `clipmindTests/UniversalClipboardDetectionTests.swift` (new)

**Interfaces:**
- Produces: `NSPasteboard.PasteboardType.universalClipboard`; `ClipboardMonitor.isRemote(types:) -> Bool` (pure, testable); remote items get `origin = .universalClipboard`, `sourceApp = "iPhone / iPad"`, `sourceBundleIdentifier = nil`, `windowTitle = nil`.

- [ ] **Step 1: Write the failing test** — `clipmindTests/UniversalClipboardDetectionTests.swift`

```swift
import XCTest
import AppKit
@testable import clipmind

final class UniversalClipboardDetectionTests: XCTestCase {
    func testDetectsRemoteMarker() {
        let types: [NSPasteboard.PasteboardType] = [.string, .universalClipboard]
        XCTAssertTrue(ClipboardMonitor.isRemote(types: types))
    }
    func testLocalHasNoMarker() {
        XCTAssertFalse(ClipboardMonitor.isRemote(types: [.string]))
    }
}
```

- [ ] **Step 2: Run, verify failure**

Run: `xcodebuild test -scheme clipmind -destination 'platform=macOS' -only-testing:clipmindTests/UniversalClipboardDetectionTests 2>&1 | tail -15`
Expected: compile failure (`universalClipboard` / `isRemote` undefined).

- [ ] **Step 3: Add the constant + pure check** in `ClipboardMonitor.swift`

```swift
extension NSPasteboard.PasteboardType {
    static let universalClipboard = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
}
```

In `ClipboardMonitor`:

```swift
static func isRemote(types: [NSPasteboard.PasteboardType]) -> Bool {
    types.contains(.universalClipboard)
}
```

- [ ] **Step 4: Branch in `handleClipboardChange`** — compute remote first and override attribution:

```swift
private func handleClipboardChange() {
    let isRemote = Self.isRemote(types: pasteboard.types ?? [])
    let metadata = MetadataExtractor.shared.extractExtendedMetadata()

    if !isRemote, metadata.bundleIdentifier == Self.appBundleIdentifier {
        return
    }

    guard let content = extractClipboardContent() else { return }
    let type = ClipboardItemType.detect(from: content)

    let item = ClipboardItem(
        content: content,
        type: type,
        timestamp: Date(),
        sourceApp: isRemote ? ClipboardOrigin.universalClipboard.displayName : metadata.appName,
        sourceBundleIdentifier: isRemote ? nil : metadata.bundleIdentifier,
        windowTitle: isRemote ? nil : metadata.windowTitle,
        activityContext: isRemote ? nil : metadata.activityContext,
        origin: isRemote ? .universalClipboard : .local
    )

    DispatchQueue.main.async { [weak self] in
        self?.onNewClipboardItem?(item)
    }
}
```

- [ ] **Step 5: Run, verify pass + build**

Run: `xcodebuild test -scheme clipmind -destination 'platform=macOS' -only-testing:clipmindTests/UniversalClipboardDetectionTests 2>&1 | tail -15`
Expected: PASS. Then `xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5` → `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add clipmind/Services/ClipboardMonitor.swift clipmindTests/UniversalClipboardDetectionTests.swift
git commit -m "feat: detect and label iPhone/iPad Universal Clipboard items"
```

> Note (privacy forward-compat, macOS 15.4+/26): a follow-up may gate the `types` check behind the new non-reading detect APIs and adopt `NSPasteboard.accessBehavior`. Out of scope for this task; tracked in the spec.

### Task 6: Device badge in the UI

**Files:**
- Modify: `clipmind/DesignSystem/Components/AppIconView.swift` (accept an `origin`; show `iphone` symbol when remote)
- Modify: `clipmind/Views/MenuBar/ClipboardItemRow.swift` (device badge when `item.origin == .universalClipboard`)

**Interfaces:**
- Consumes: `ClipboardItem.origin`, `ClipboardOrigin.deviceSymbolName`.

- [ ] **Step 1: Add an `origin` parameter to `AppIconView`** (default `.local`); when `origin.deviceSymbolName != nil`, render that SF Symbol instead of resolving a bundle icon.

```swift
let origin: ClipboardOrigin
init(bundleIdentifier: String?, appName: String, size: CGFloat = DesignTokens.Sizes.appIconMD, origin: ClipboardOrigin = .local) {
    self.bundleIdentifier = bundleIdentifier
    self.appName = appName
    self.size = size
    self.origin = origin
}
```

In `body`, before the existing bundle-icon path:

```swift
if let symbol = origin.deviceSymbolName {
    Image(systemName: symbol)
        .font(.system(size: size * 0.7, weight: .regular))
        .foregroundStyle(DesignTokens.Colors.accentPrimary)
        .frame(width: size, height: size)
} else {
    // existing bundle/app-icon resolution
}
```

- [ ] **Step 2: Pass origin + add a badge in `ClipboardItemRow`**

Pass `origin: item.origin` into `AppIconView(...)`. In the metadata row, when remote, prepend a small badge:

```swift
if item.origin == .universalClipboard {
    HStack(spacing: 3) {
        Image(systemName: "iphone").font(.system(size: 8, weight: .medium))
        Text("iPhone").font(.system(size: 10, weight: .medium))
    }
    .foregroundStyle(DesignTokens.Colors.accentSecondary)
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add clipmind/DesignSystem/Components/AppIconView.swift clipmind/Views/MenuBar/ClipboardItemRow.swift
git commit -m "feat: show device badge for iPhone/iPad clipboard items"
```

---

## Feature A — Card-Shuffle Menu Carousel

### File structure
- Create: `clipmind/Views/MenuBar/CardCarousel.swift` (CardCarousel + CarouselCard + CarouselIndicator + the pure `deckTransform` helper).
- Modify: `clipmind/Views/MenuBar/ClipboardMenuPopover.swift` (swap list → carousel; tap copies + closes).
- Modify: `clipmind/Views/MenuBar/MenuBarView.swift` (pass a close callback; popover height).
- Modify: `clipmind/Services/ClipboardStore.swift` (`maxRecentItems` 5 → 8).
- Test: `clipmindTests/DeckTransformTests.swift` (new).

### Task 7: Deck geometry helper (TDD) + carousel views

**Files:**
- Create: `clipmind/Views/MenuBar/CardCarousel.swift`
- Test: `clipmindTests/DeckTransformTests.swift`

**Interfaces:**
- Produces: `struct DeckTransform { let offsetX: CGFloat; let scale: CGFloat; let rotation: Double; let opacity: Double; let zIndex: Double }` and `func deckTransform(offset: Int) -> DeckTransform`; `struct CardCarousel: View` with `init(items:currentIndex:onActivate:)`.

- [ ] **Step 1: Write the failing test** — `clipmindTests/DeckTransformTests.swift`

```swift
import XCTest
@testable import clipmind

final class DeckTransformTests: XCTestCase {
    func testFrontCardIsSharpAndCentered() {
        let t = deckTransform(offset: 0)
        XCTAssertEqual(t.offsetX, 0)
        XCTAssertEqual(t.scale, 1, accuracy: 0.001)
        XCTAssertEqual(t.opacity, 1, accuracy: 0.001)
    }
    func testNeighborsShrinkAndDim() {
        let one = deckTransform(offset: 1)
        XCTAssertLessThan(one.scale, 1)
        XCTAssertLessThan(one.opacity, 1)
        XCTAssertGreaterThan(one.offsetX, 0)
    }
    func testFarCardsHidden() {
        XCTAssertEqual(deckTransform(offset: 3).opacity, 0, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run, verify failure**

Run: `xcodebuild test -scheme clipmind -destination 'platform=macOS' -only-testing:clipmindTests/DeckTransformTests 2>&1 | tail -15`
Expected: compile failure (`deckTransform` undefined).

- [ ] **Step 3: Implement `deckTransform` + the views** in `clipmind/Views/MenuBar/CardCarousel.swift`

```swift
import SwiftUI

struct DeckTransform {
    let offsetX: CGFloat
    let scale: CGFloat
    let rotation: Double
    let opacity: Double
    let zIndex: Double
}

func deckTransform(offset: Int) -> DeckTransform {
    let a = abs(offset)
    if a > 2 {
        return DeckTransform(offsetX: CGFloat(offset) * 60, scale: 0.7, rotation: Double(offset) * 6, opacity: 0, zIndex: 0)
    }
    let opacity = a == 0 ? 1.0 : (a == 1 ? 0.5 : 0.24)
    return DeckTransform(
        offsetX: CGFloat(offset) * 84,
        scale: 1 - CGFloat(a) * 0.12,
        rotation: Double(offset) * 5,
        opacity: opacity,
        zIndex: Double(20 - a)
    )
}
```

Then implement `CardCarousel` (binding `currentIndex`, `onActivate`), `CarouselCard` (reuses `AppIconView`, `ContentTypeBadge`, `truncatedPreview`, the device badge for remote origin), and `CarouselIndicator` (dots + `n / total`), per spec §"Components". Animate index changes with `DesignTokens.Animation.spring`; honor `@Environment(\.accessibilityReduceMotion)` (crossfade, no rotation/scale when reduced).

- [ ] **Step 4: Run, verify pass**

Run: `xcodebuild test -scheme clipmind -destination 'platform=macOS' -only-testing:clipmindTests/DeckTransformTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add clipmind/Views/MenuBar/CardCarousel.swift clipmindTests/DeckTransformTests.swift
git commit -m "feat: card-shuffle carousel views with tested deck geometry"
```

### Task 8: Navigation inputs (keys/scroll/drag) + reduced motion

**Files:**
- Modify: `clipmind/Views/MenuBar/CardCarousel.swift`

- [ ] **Step 1: Add chevron buttons** (dimmed/disabled at ends) calling `advance(by:)` which clamps `currentIndex` to `0..<items.count` and animates with the spring.

- [ ] **Step 2: Add keyboard nav** — `.onKeyPress(.leftArrow)` / `.onKeyPress(.rightArrow)` (macOS 14+) on the carousel container, calling `advance(by:)`.

- [ ] **Step 3: Add scroll/swipe** — an `NSViewRepresentable` scroll monitor (or `.onScroll`-equivalent) that, debounced ~320ms, calls `advance(by:)` based on dominant `deltaX`/`deltaY` sign.

- [ ] **Step 4: Add drag** — `DragGesture(minimumDistance: 10)` translating the front card; on end, advance if `|translation.width| > 46`, else spring back.

- [ ] **Step 5: Build**

Run: `xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add clipmind/Views/MenuBar/CardCarousel.swift
git commit -m "feat: carousel keyboard, scroll, and drag navigation"
```

### Task 9: Swap carousel into the popover + close-on-copy + deck size

**Files:**
- Modify: `clipmind/Views/MenuBar/ClipboardMenuPopover.swift` (replace `itemsList`)
- Modify: `clipmind/Views/MenuBar/MenuBarView.swift` (close callback; `contentSize` height)
- Modify: `clipmind/Services/ClipboardStore.swift` (`maxRecentItems = 8`)

**Interfaces:**
- Consumes: `CardCarousel` (Task 7-8).

- [ ] **Step 1: Add a close callback** — give `ClipboardMenuPopover` an `onClose: () -> Void` (set by `MenuBarController` to `closePopover`). `handleItemTap` becomes: copy → toast/haptic → `onClose()`.

- [ ] **Step 2: Replace `itemsList`** body with:

```swift
@State private var carouselIndex = 0
...
CardCarousel(items: clipboardStore.recentItems, currentIndex: $carouselIndex) { item in
    handleItemTap(item)
}
.onChange(of: clipboardStore.recentItems.count) { _ in carouselIndex = 0 }
```

Keep `header`, `footer`, `emptyState`. Preserve the right-click context menu (Copy / Delete) on the card.

- [ ] **Step 2b: In `handleItemTap`**, after the existing copy + haptic, call `onClose()`.

- [ ] **Step 3: Wire the close callback + height** in `MenuBarView.swift` — pass `onClose: { [weak self] in self?.closePopover() }` into `ClipboardMenuPopover(...)`; set `popover?.contentSize` height to ~340.

- [ ] **Step 4: Bump deck size** — `ClipboardStore.maxRecentItems` from `5` to `8`.

- [ ] **Step 5: Build**

Run: `xcodebuild -scheme clipmind -configuration Debug build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add clipmind/Views/MenuBar/ClipboardMenuPopover.swift clipmind/Views/MenuBar/MenuBarView.swift clipmind/Services/ClipboardStore.swift
git commit -m "feat: replace popover list with card-shuffle carousel (8 recent), copy closes menu"
```

> Final manual check (user): open the menu, shuffle via arrows/keys/scroll/drag, tap to copy (menu closes), reduced-motion crossfade, and an iPhone-origin item shows the device badge.

---

## Self-Review

- **Spec coverage:** Logo (master SVGs, full icon set, template menu-bar glyph) ✓ Tasks 1-2. iPhone capture (detection, label, origin field, migration, badge) ✓ Tasks 3-6. Carousel (deck, nav, indicator, tap-to-copy-close, 8 items, reduced-motion) ✓ Tasks 7-9. macOS-15.4 privacy detect-API note flagged as a tracked follow-up (spec Feature C) — intentionally out of this plan's scope.
- **Placeholder scan:** UI sub-steps in Tasks 7-9 reference spec §Components for exhaustive view code rather than inlining every SwiftUI line; the tested logic (`deckTransform`, `isRemote`, origin Codable, DB migration) has complete code. Acceptable: views are verified by build + manual check, logic by XCTest.
- **Type consistency:** `ClipboardOrigin` (.local/.universalClipboard), `origin` field, `deckTransform`/`DeckTransform`, `isRemote(types:)`, `onClose`/`onActivate` used consistently across tasks.
- **Open question resolved for Phase 1:** the carousel keeps its own `CarouselCard` (wrapping shared sub-pieces); a fully shared lean row is deferred to Phase 2's dashboard work.
