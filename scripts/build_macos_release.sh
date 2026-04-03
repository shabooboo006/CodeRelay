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
VERSION="${VERSION:-0.1.0-alpha.6}"
BUILD_NUMBER="${BUILD_NUMBER:-6}"
SIGNING_MODE="${SIGNING_MODE:-adhoc}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-}"

info() {
  printf '%s\n' "$*" >&2
}

detect_app_sign_identity() {
  local output
  if [[ -n "$KEYCHAIN_PATH" ]]; then
    output="$(security find-identity -p codesigning -v "$KEYCHAIN_PATH" 2>/dev/null || true)"
  else
    output="$(security find-identity -p codesigning -v 2>/dev/null || true)"
  fi

  print -r -- "$output" | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1
}

configure_signing() {
  case "$SIGNING_MODE" in
    adhoc)
      CODESIGN_ARGS=(--force --sign -)
      ;;
    developer-id)
      if [[ -z "$APP_SIGN_IDENTITY" ]]; then
        APP_SIGN_IDENTITY="$(detect_app_sign_identity)"
      fi
      if [[ -z "$APP_SIGN_IDENTITY" ]]; then
        info "ERROR: SIGNING_MODE=developer-id but no Developer ID Application certificate was found."
        info "Set APP_SIGN_IDENTITY explicitly or install a Developer ID Application certificate."
        exit 1
      fi
      CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_SIGN_IDENTITY")
      ;;
    *)
      info "ERROR: Unsupported SIGNING_MODE '$SIGNING_MODE'. Expected 'adhoc' or 'developer-id'."
      exit 1
      ;;
  esac
}

collect_nested_code_targets() {
  if [[ ! -d "$CONTENTS_DIR" ]]; then
    return
  fi

  find "$CONTENTS_DIR" \
    \( \
      -type d \( -name '*.app' -o -name '*.appex' -o -name '*.framework' -o -name '*.xpc' \) \
      -o -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' \) \
    \) \
    -print | awk -F/ '{ print NF "\t" $0 }' | sort -rn | cut -f2-
}

sign_release_bundle() {
  configure_signing

  chmod -R u+w "$APP_DIR"
  find "$APP_DIR" -exec xattr -c {} + 2>/dev/null || true
  find "$APP_DIR" -name '._*' -delete

  local target
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    codesign "${CODESIGN_ARGS[@]}" "$target"
  done < <(collect_nested_code_targets)

  codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
}

rm -rf "$BUILD_DIR" "$APP_DIR"
mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

swift build -c release --product "$PRODUCT_NAME" --package-path "$ROOT_DIR"

if [[ ! -d "$ICONSET_SOURCE" ]]; then
  info "ERROR: Missing app icon source at $ICONSET_SOURCE"
  exit 1
fi

zsh "$ICON_BUILD_SCRIPT" "$ICONSET_SOURCE" "$ICON_ICNS_PATH" >/dev/null

BIN_DIR="$(swift build -c release --product "$PRODUCT_NAME" --package-path "$ROOT_DIR" --show-bin-path)"
BIN_PATH="$BIN_DIR/$PRODUCT_NAME"
cp "$BIN_PATH" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

cp "$ICON_ICNS_PATH" "$RESOURCES_DIR/Icon.icns"

copied_resource_bundle=0
while IFS= read -r -d '' bundle_path; do
  bundle_name="$(basename "$bundle_path")"
  cp -R "$bundle_path" "$RESOURCES_DIR/$bundle_name"
  copied_resource_bundle=1
done < <(find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -type d -print0)

if [[ "$copied_resource_bundle" -eq 0 ]]; then
  info "ERROR: SwiftPM did not emit a resource bundle for $PRODUCT_NAME in $BIN_DIR"
  exit 1
fi

sed \
  -e "s/__VERSION__/$VERSION/g" \
  -e "s/__BUILD__/$BUILD_NUMBER/g" \
  "$PLIST_TEMPLATE" > "$PLIST_PATH"

touch "$CONTENTS_DIR/PkgInfo"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

sign_release_bundle

codesign --verify --deep --strict --verbose=2 "$APP_DIR" >/dev/null

echo "$APP_DIR"
