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
