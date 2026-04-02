#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="${1:-$ROOT_DIR/Packaging/macOS/AppIcon.appiconset}"
OUTPUT_PATH="${2:-$ROOT_DIR/Packaging/macOS/Icon.icns}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: Missing app icon set at $SOURCE_DIR" >&2
  exit 1
fi

for filename in 16.png 32.png 64.png 128.png 256.png 512.png 1024.png; do
  if [[ ! -f "$SOURCE_DIR/$filename" ]]; then
    echo "ERROR: Missing $filename in $SOURCE_DIR" >&2
    exit 1
  fi
done

TMP_DIR="$(mktemp -d)"
ICONSET_DIR="$TMP_DIR/Icon.iconset"
mkdir -p "$ICONSET_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

cp "$SOURCE_DIR/16.png" "$ICONSET_DIR/icon_16x16.png"
cp "$SOURCE_DIR/32.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "$SOURCE_DIR/32.png" "$ICONSET_DIR/icon_32x32.png"
cp "$SOURCE_DIR/64.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "$SOURCE_DIR/128.png" "$ICONSET_DIR/icon_128x128.png"
cp "$SOURCE_DIR/256.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "$SOURCE_DIR/256.png" "$ICONSET_DIR/icon_256x256.png"
cp "$SOURCE_DIR/512.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "$SOURCE_DIR/512.png" "$ICONSET_DIR/icon_512x512.png"
cp "$SOURCE_DIR/1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

mkdir -p "$(dirname "$OUTPUT_PATH")"
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_PATH"

echo "$OUTPUT_PATH"
