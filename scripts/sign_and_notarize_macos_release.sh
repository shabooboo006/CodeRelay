#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

export SIGNING_MODE="${SIGNING_MODE:-developer-id}"
export NOTARIZE="${NOTARIZE:-1}"
export NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-CodeRelayNotary}"
export PACKAGE_FORMATS="${PACKAGE_FORMATS:-zip dmg}"

exec zsh "$ROOT_DIR/scripts/package_macos_release.sh"
