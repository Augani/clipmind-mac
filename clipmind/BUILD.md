# ClipMind - Build & Distribution Guide

Complete guide for building, testing, and distributing ClipMind.

## Prerequisites

### Development Environment
- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Command Line Tools**: `xcode-select --install`

### Apple Developer Account
- **Free Account**: For development and personal use
- **Paid Account** ($99/year): Required for distribution and notarization

## Quick Start

### 1. Clone and Open

```bash
git clone https://github.com/yourusername/clipmind.git
cd clipmind/clipmind
open clipmind.xcodeproj
```

### 2. Build and Run

In Xcode:
1. Select the `clipmind` scheme
2. Choose "My Mac" as destination
3. Press ⌘+R to build and run

Or via command line:
```bash
xcodebuild -scheme clipmind -configuration Debug build
```

### 3. Grant Permissions

On first launch:
1. System Settings → Privacy & Security → Accessibility
2. Enable ClipMind
3. Restart the app

## Development Build

### Debug Configuration

```bash
# Build debug version
xcodebuild \
  -scheme clipmind \
  -configuration Debug \
  -derivedDataPath ./build \
  build

# Run tests
xcodebuild \
  -scheme clipmind \
  -configuration Debug \
  test
```

### Debug Settings

Enable debug features:
```bash
# Enable debug logging
defaults write com.clipmind.app DebugLoggingEnabled -bool true

# Custom database path
defaults write com.clipmind.app DatabasePath -string "~/Desktop/clipmind-dev.db"

# Disable iCloud sync
defaults write com.clipmind.app DisableiCloudSync -bool true
```

View logs:
```bash
# Live log streaming
log stream --predicate 'subsystem == "com.clipmind.app"' --level debug

# Or use Console.app and filter by "clipmind"
```

## Testing

### Running Tests

**Unit Tests**:
```bash
# All tests
xcodebuild test -scheme clipmind -destination 'platform=macOS'

# Specific test
xcodebuild test -scheme clipmind -only-testing:clipmindTests/DatabaseServiceTests

# In Xcode: ⌘+U
```

**Test Coverage**:
```bash
# Generate coverage report
xcodebuild test \
  -scheme clipmind \
  -enableCodeCoverage YES \
  -derivedDataPath ./build

# View coverage in Xcode: Report Navigator (⌘+9) → Coverage
```

### Performance Testing

**Instruments**:
```bash
# Profile with Instruments
xcodebuild build -scheme clipmind -configuration Release
instruments -t "Time Profiler" ./build/Release/clipmind.app

# Or in Xcode: Product → Profile (⌘+I)
```

**Database Performance**:
```bash
# Open database
sqlite3 ~/Library/Application\ Support/ClipMind/clipboard.db

# Analyze query plans
EXPLAIN QUERY PLAN SELECT * FROM clipboard_items WHERE workspace_id = 'xxx';

# Check indexes
.indexes clipboard_items

# Vacuum database
VACUUM;
ANALYZE;
```

## Release Build

### 1. Update Version

Update version in Xcode:
1. Select project in navigator
2. Select target `clipmind`
3. General → Identity
4. Update Version (e.g., 1.0.0)
5. Update Build (e.g., 1)

Or via `agvtool`:
```bash
# Set version
agvtool new-marketing-version 1.0.0

# Increment build number
agvtool next-version -all
```

### 2. Release Configuration

```bash
# Build release version
xcodebuild \
  -scheme clipmind \
  -configuration Release \
  -derivedDataPath ./build \
  build

# Output: ./build/Build/Products/Release/clipmind.app
```

### 3. Code Signing

#### Development Signing (Free Account)

In Xcode:
1. Signing & Capabilities tab
2. Select "Automatically manage signing"
3. Team: Your Personal Team
4. Bundle Identifier: com.yourname.clipmind

#### Distribution Signing (Paid Account)

In Xcode:
1. Signing & Capabilities tab
2. Signing: Automatically manage
3. Team: Your Developer Team
4. Provisioning Profile: Xcode Managed Profile

Or manual signing:
```bash
# Create signing certificate in Keychain Access
# Import Developer ID certificate from Apple Developer

# Build with manual signing
xcodebuild \
  -scheme clipmind \
  -configuration Release \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
  build
```

### 4. Archive

In Xcode:
1. Product → Archive (⌘+B, then Archive)
2. Wait for archiving to complete
3. Organizer window opens automatically

Or via command line:
```bash
xcodebuild \
  -scheme clipmind \
  -configuration Release \
  -archivePath ./build/clipmind.xcarchive \
  archive
```

## Distribution

### Direct Distribution (DMG)

#### 1. Create App Bundle

```bash
# Copy app to staging directory
mkdir -p ./dist
cp -R ./build/Build/Products/Release/clipmind.app ./dist/
```

#### 2. Create DMG

Using `create-dmg` (install via Homebrew):
```bash
brew install create-dmg

create-dmg \
  --volname "ClipMind" \
  --volicon "./clipmind/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "clipmind.app" 200 190 \
  --hide-extension "clipmind.app" \
  --app-drop-link 600 185 \
  "ClipMind-1.0.0.dmg" \
  "./dist/"
```

Or manually:
```bash
# Create DMG
hdiutil create -volname ClipMind -srcfolder ./dist -ov -format UDZO ClipMind-1.0.0.dmg

# Verify
hdiutil verify ClipMind-1.0.0.dmg
```

#### 3. Sign DMG

```bash
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --timestamp \
  --options runtime \
  ClipMind-1.0.0.dmg
```

### Notarization (Required for Distribution)

#### 1. Upload to Apple

```bash
# Create app-specific password at appleid.apple.com

# Store credentials in keychain
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID"

# Submit for notarization
xcrun notarytool submit ClipMind-1.0.0.dmg \
  --keychain-profile "notarytool-profile" \
  --wait

# Check status
xcrun notarytool info SUBMISSION_ID \
  --keychain-profile "notarytool-profile"
```

#### 2. Staple Ticket

```bash
# Staple notarization ticket to DMG
xcrun stapler staple ClipMind-1.0.0.dmg

# Verify
xcrun stapler validate ClipMind-1.0.0.dmg
spctl -a -t open --context context:primary-signature -v ClipMind-1.0.0.dmg
```

### Mac App Store Distribution

#### 1. App Store Preparation

1. Create App ID in Apple Developer Portal
2. Create provisioning profile for Mac App Store
3. Update entitlements for App Store

#### 2. Archive for App Store

In Xcode:
1. Product → Archive
2. Organizer → Distribute App
3. Mac App Store → Next
4. Upload → Next
5. Automatically manage signing
6. Upload

#### 3. App Store Connect

1. Go to App Store Connect
2. Create new app
3. Fill in metadata:
   - Name: ClipMind
   - Subtitle: Intelligent Clipboard Manager
   - Categories: Productivity, Utilities
   - Screenshots (required sizes)
   - Description and keywords
4. Submit for review

## Continuous Integration

### GitHub Actions

Create `.github/workflows/build.yml`:

```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Build
        run: |
          xcodebuild build \
            -scheme clipmind \
            -configuration Release \
            -derivedDataPath ./build

      - name: Test
        run: |
          xcodebuild test \
            -scheme clipmind \
            -destination 'platform=macOS'

      - name: Archive
        if: github.ref == 'refs/heads/main'
        run: |
          xcodebuild archive \
            -scheme clipmind \
            -configuration Release \
            -archivePath ./build/clipmind.xcarchive
```

### Release Automation

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3

      - name: Build Release
        run: |
          xcodebuild archive \
            -scheme clipmind \
            -configuration Release \
            -archivePath ./build/clipmind.xcarchive

      - name: Create DMG
        run: |
          # Create DMG script here

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: ClipMind-${{ github.ref_name }}.dmg
          generate_release_notes: true
```

## Troubleshooting

### Build Errors

**Missing Swift Package Dependencies**:
```bash
# Reset package cache
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Resolve packages in Xcode
File → Packages → Reset Package Caches
File → Packages → Resolve Package Versions
```

**Code Signing Issues**:
```bash
# Clean build folder
xcodebuild clean -scheme clipmind

# Remove derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Check certificates
security find-identity -v -p codesigning
```

**Accessibility Permission**:
```bash
# Reset TCC database (requires restart)
tccutil reset Accessibility com.clipmind.app

# Or manually in System Settings
```

### Runtime Issues

**Database Migration**:
```bash
# Backup database
cp ~/Library/Application\ Support/ClipMind/clipboard.db \
   ~/Library/Application\ Support/ClipMind/clipboard.db.backup

# Reset database (warning: deletes all data)
rm ~/Library/Application\ Support/ClipMind/clipboard.db
```

**Memory Issues**:
```bash
# Monitor memory usage
instruments -t "Allocations" ./build/Release/clipmind.app

# Check for leaks
instruments -t "Leaks" ./build/Release/clipmind.app
```

## Performance Optimization

### Build Optimization

**Optimize Build Time**:
```bash
# Parallel builds
defaults write com.apple.dt.XCBuild EnableSwiftBuildSystemIntegration 1

# Disable code coverage for faster builds
xcodebuild build -configuration Release -enableCodeCoverage NO
```

**Optimize Binary Size**:
```bash
# Strip symbols
strip -x ./build/Release/clipmind.app/Contents/MacOS/clipmind

# Check size
du -h ./build/Release/clipmind.app
```

### Runtime Optimization

**Database Optimization**:
```bash
# Optimize database
sqlite3 ~/Library/Application\ Support/ClipMind/clipboard.db "VACUUM; ANALYZE;"

# Enable memory-mapped I/O
sqlite3 ~/Library/Application\ Support/ClipMind/clipboard.db "PRAGMA mmap_size=33554432;"
```

## Distribution Checklist

Before releasing:

- [ ] Version number updated
- [ ] Build number incremented
- [ ] All tests passing
- [ ] No compiler warnings
- [ ] Code signed with Developer ID
- [ ] DMG created and tested
- [ ] Notarization complete
- [ ] Tested on clean macOS install
- [ ] README updated
- [ ] CHANGELOG updated
- [ ] Screenshots prepared
- [ ] Release notes written

## Support

- **Build Issues**: Check Xcode build log
- **Runtime Issues**: Check Console.app logs
- **Code Signing**: Apple Developer Forums
- **Notarization**: Apple Notarization Guide

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)

---

Happy Building! 🚀
