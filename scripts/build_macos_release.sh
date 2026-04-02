#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/dist/build"
APP_DIR="$ROOT_DIR/dist/CodeRelay.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_TEMPLATE="$ROOT_DIR/Packaging/macOS/Info.plist"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
ICONSET_SOURCE="$ROOT_DIR/Packaging/macOS/AppIcon.appiconset"
ICON_BUILD_SCRIPT="$ROOT_DIR/scripts/build_icon.sh"
ICON_ICNS_PATH="$ROOT_DIR/Packaging/macOS/Icon.icns"
PRODUCT_NAME="CodeRelayApp"
APP_NAME="CodeRelay"
VERSION="${VERSION:-0.1.0-alpha.3}"
BUILD_NUMBER="${BUILD_NUMBER:-3}"

rm -rf "$BUILD_DIR" "$APP_DIR"
mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

swift build -c release --product "$PRODUCT_NAME" --package-path "$ROOT_DIR"

if [[ ! -d "$ICONSET_SOURCE" ]]; then
  echo "ERROR: Missing app icon source at $ICONSET_SOURCE" >&2
  exit 1
fi

zsh "$ICON_BUILD_SCRIPT" "$ICONSET_SOURCE" "$ICON_ICNS_PATH" >/dev/null

BIN_DIR="$(swift build -c release --product "$PRODUCT_NAME" --package-path "$ROOT_DIR" --show-bin-path)"
BIN_PATH="$BIN_DIR/$PRODUCT_NAME"
cp "$BIN_PATH" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

cp "$ICON_ICNS_PATH" "$RESOURCES_DIR/Icon.icns"

find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -type d -print0 | while IFS= read -r -d '' bundle_path; do
  cp -R "$bundle_path" "$RESOURCES_DIR/$(basename "$bundle_path")"
done

sed \
  -e "s/__VERSION__/$VERSION/g" \
  -e "s/__BUILD__/$BUILD_NUMBER/g" \
  "$PLIST_TEMPLATE" > "$PLIST_PATH"

touch "$CONTENTS_DIR/PkgInfo"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

find "$APP_DIR" -exec xattr -c {} + 2>/dev/null || true

codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "$APP_DIR"
