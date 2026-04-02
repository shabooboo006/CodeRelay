#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/stage"
APP_DIR="$DIST_DIR/CodeRelay.app"
VERSION="${VERSION:-0.1.0-alpha.4}"
BUILD_NUMBER="${BUILD_NUMBER:-4}"
PKG_PATH="$DIST_DIR/CodeRelay-$VERSION.pkg"
DMG_PATH="$DIST_DIR/CodeRelay-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/CodeRelay-$VERSION-macOS.zip"

zsh "$ROOT_DIR/scripts/build_macos_release.sh" >/dev/null

rm -rf "$STAGE_DIR" "$PKG_PATH" "$DMG_PATH" "$ZIP_PATH"
mkdir -p "$STAGE_DIR"
COPYFILE_DISABLE=1 ditto "$APP_DIR" "$STAGE_DIR/CodeRelay.app"
ln -s /Applications "$STAGE_DIR/Applications"
find "$STAGE_DIR" -name '._*' -delete

COPYFILE_DISABLE=1 ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

COPYFILE_DISABLE=1 pkgbuild \
  --component "$APP_DIR" \
  --install-location /Applications \
  --version "$VERSION" \
  "$PKG_PATH"

hdiutil create \
  -volname "CodeRelay" \
  -srcfolder "$STAGE_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH" >/dev/null

printf '%s\n' "$APP_DIR" "$ZIP_PATH" "$PKG_PATH" "$DMG_PATH"
