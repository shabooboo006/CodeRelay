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
PRODUCT_NAME="CodeRelayApp"
APP_NAME="CodeRelay"
VERSION="${VERSION:-0.1.0-alpha.1}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

rm -rf "$BUILD_DIR" "$APP_DIR"
mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

swift build -c release --product "$PRODUCT_NAME" --package-path "$ROOT_DIR"

BIN_PATH="$(swift build -c release --product "$PRODUCT_NAME" --package-path "$ROOT_DIR" --show-bin-path)/$PRODUCT_NAME"
cp "$BIN_PATH" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

sed \
  -e "s/__VERSION__/$VERSION/g" \
  -e "s/__BUILD__/$BUILD_NUMBER/g" \
  "$PLIST_TEMPLATE" > "$PLIST_PATH"

touch "$CONTENTS_DIR/PkgInfo"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

find "$APP_DIR" -exec xattr -c {} + 2>/dev/null || true

codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "$APP_DIR"
