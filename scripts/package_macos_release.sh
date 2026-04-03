#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/stage"
APP_DIR="$DIST_DIR/CodeRelay.app"
VERSION="${VERSION:-0.1.0-alpha.5}"
BUILD_NUMBER="${BUILD_NUMBER:-5}"
SIGNING_MODE="${SIGNING_MODE:-adhoc}"
NOTARIZE="${NOTARIZE:-0}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
INSTALLER_SIGN_IDENTITY="${INSTALLER_SIGN_IDENTITY:-}"
TMP_NOTARY_ZIP="$DIST_DIR/CodeRelay-$VERSION-notary.zip"
PKG_PATH="$DIST_DIR/CodeRelay-$VERSION.pkg"
DMG_PATH="$DIST_DIR/CodeRelay-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/CodeRelay-$VERSION-macOS.zip"
PACKAGE_FORMATS="${PACKAGE_FORMATS:-zip pkg dmg}"

info() {
  printf '%s\n' "$*" >&2
}

cleanup_tmp_artifacts() {
  rm -f "$TMP_NOTARY_ZIP"
}

has_format() {
  local format_name="$1"
  [[ " $PACKAGE_FORMATS " == *" $format_name "* ]]
}

detect_installer_identity() {
  local output
  if [[ -n "$KEYCHAIN_PATH" ]]; then
    output="$(security find-identity -v "$KEYCHAIN_PATH" 2>/dev/null || true)"
  else
    output="$(security find-identity -v 2>/dev/null || true)"
  fi

  print -r -- "$output" | sed -n 's/.*"\(Developer ID Installer: [^"]*\)".*/\1/p' | head -n 1
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

ensure_app_identity() {
  if [[ "$SIGNING_MODE" != "developer-id" ]]; then
    return
  fi

  if [[ -z "$APP_SIGN_IDENTITY" ]]; then
    APP_SIGN_IDENTITY="$(detect_app_sign_identity)"
  fi

  if [[ -z "$APP_SIGN_IDENTITY" ]]; then
    info "ERROR: SIGNING_MODE=developer-id but no Developer ID Application certificate was found."
    info "Set APP_SIGN_IDENTITY explicitly or install a Developer ID Application certificate."
    exit 1
  fi
}

ensure_installer_identity() {
  if [[ "$SIGNING_MODE" != "developer-id" ]]; then
    return
  fi

  if [[ -z "$INSTALLER_SIGN_IDENTITY" ]]; then
    INSTALLER_SIGN_IDENTITY="$(detect_installer_identity)"
  fi

  if [[ -z "$INSTALLER_SIGN_IDENTITY" ]]; then
    info "ERROR: SIGNING_MODE=developer-id but no Developer ID Installer certificate was found."
    info "Set INSTALLER_SIGN_IDENTITY explicitly or install a Developer ID Installer certificate."
    exit 1
  fi
}

validate_release_app() {
  codesign --verify --deep --strict --verbose=4 "$APP_DIR"
  spctl --assess --type execute --verbose=4 "$APP_DIR"
}

notarize_archive() {
  local archive_path="$1"
  local -a args
  args=(submit "$archive_path" --keychain-profile "$NOTARYTOOL_PROFILE" --wait)
  if [[ -n "$KEYCHAIN_PATH" ]]; then
    args+=(--keychain "$KEYCHAIN_PATH")
  fi
  xcrun notarytool "${args[@]}"
}

create_stage() {
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR"
  COPYFILE_DISABLE=1 ditto "$APP_DIR" "$STAGE_DIR/CodeRelay.app"
  ln -s /Applications "$STAGE_DIR/Applications"
  find "$STAGE_DIR" -name '._*' -delete
}

build_zip() {
  rm -f "$ZIP_PATH"
  COPYFILE_DISABLE=1 ditto --norsrc -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
}

build_pkg() {
  rm -f "$PKG_PATH"
  if [[ "$SIGNING_MODE" == "developer-id" ]]; then
    ensure_installer_identity
    pkgbuild \
      --component "$APP_DIR" \
      --install-location /Applications \
      --version "$VERSION" \
      --sign "$INSTALLER_SIGN_IDENTITY" \
      --timestamp \
      "$PKG_PATH"
  else
    pkgbuild \
      --component "$APP_DIR" \
      --install-location /Applications \
      --version "$VERSION" \
      "$PKG_PATH"
  fi
}

build_dmg() {
  create_stage
  rm -f "$DMG_PATH"
  hdiutil create \
    -volname "CodeRelay" \
    -srcfolder "$STAGE_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

  if [[ "$SIGNING_MODE" == "developer-id" ]]; then
    ensure_app_identity
    codesign --force --timestamp --sign "$APP_SIGN_IDENTITY" "$DMG_PATH"
  fi
}

prepare_notarized_app() {
  [[ "$SIGNING_MODE" == "developer-id" ]] || {
    info "ERROR: NOTARIZE=1 requires SIGNING_MODE=developer-id."
    exit 1
  }
  [[ -n "$NOTARYTOOL_PROFILE" ]] || {
    info "ERROR: NOTARIZE=1 requires NOTARYTOOL_PROFILE."
    exit 1
  }

  COPYFILE_DISABLE=1 ditto --norsrc -c -k --keepParent "$APP_DIR" "$TMP_NOTARY_ZIP"
  notarize_archive "$TMP_NOTARY_ZIP"
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
}

prepare_notarized_pkg() {
  notarize_archive "$PKG_PATH"
  xcrun stapler staple "$PKG_PATH"
  xcrun stapler validate "$PKG_PATH"
}

prepare_notarized_dmg() {
  notarize_archive "$DMG_PATH"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
}

trap cleanup_tmp_artifacts EXIT

zsh "$ROOT_DIR/scripts/build_macos_release.sh" >/dev/null

rm -rf "$STAGE_DIR" "$PKG_PATH" "$DMG_PATH" "$ZIP_PATH" "$TMP_NOTARY_ZIP"

if [[ "$NOTARIZE" == "1" ]]; then
  prepare_notarized_app
fi

if has_format zip; then
  build_zip
fi

if has_format pkg; then
  build_pkg
fi

if [[ "$NOTARIZE" == "1" ]] && has_format pkg; then
  prepare_notarized_pkg
fi

if has_format dmg; then
  build_dmg
fi

if [[ "$NOTARIZE" == "1" ]] && has_format dmg; then
  prepare_notarized_dmg
fi

validate_release_app

printf '%s\n' "$APP_DIR"
if has_format zip; then
  printf '%s\n' "$ZIP_PATH"
fi
if has_format pkg; then
  printf '%s\n' "$PKG_PATH"
fi
if has_format dmg; then
  printf '%s\n' "$DMG_PATH"
fi
