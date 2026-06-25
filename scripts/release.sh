#!/usr/bin/env bash
#
# ClipMind release builder — Developer ID sign → notarize → staple → DMG.
#
# ONE-TIME SETUP (you run this; your password goes into the keychain, never this repo):
#   xcrun notarytool store-credentials clipmind-notary \
#     --apple-id "<your-apple-id>" \
#     --team-id 864H636QW4 \
#     --password "<your-app-specific-password>"
#
# THEN, to cut a release:
#   ./scripts/release.sh 1.0.0
#   gh release create v1.0.0 dist/ClipMind-1.0.0.dmg \
#     --repo Augani/clipmind-mac --title "ClipMind 1.0.0" --notes "First public release."
#
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version>  (e.g. 1.0.0)}"
SCHEME="clipmind"
APP_NAME="clipmind"
TEAM_ID="864H636QW4"
SIGN_ID="Developer ID Application: Augustus Otu (${TEAM_ID})"
NOTARY_PROFILE="clipmind-notary"

BUILD_DIR="build/release"
APP="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
DMG="dist/ClipMind-${VERSION}.dmg"

mkdir -p dist
rm -rf "$BUILD_DIR"

echo "==> Building Release (Developer ID + hardened runtime)…"
xcodebuild -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--options runtime --timestamp" \
  clean build

echo "==> Packaging DMG…"
rm -f "$DMG"
hdiutil create -volname "ClipMind" -srcfolder "$APP" -ov -format UDZO "$DMG"
codesign --force --sign "$SIGN_ID" --timestamp "$DMG"

echo "==> Notarizing (credentials read from keychain profile '${NOTARY_PROFILE}')…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling…"
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"

echo "==> Verifying…"
spctl --assess --type open --context context:primary-signature -v "$DMG" || true

echo ""
echo "Done: $DMG (signed, notarized, stapled)"
echo "Publish it with:"
echo "  gh release create v${VERSION} \"$DMG\" --repo Augani/clipmind-mac --title \"ClipMind ${VERSION}\" --notes \"…\""
