# Quick Task 260402-opy

## Scope

Redesign the CodeRelay management window and menu bar popup to better match CodexBar's cleaner macOS utility style: clearer sectioning, less crowding, and stronger visual hierarchy.

## Constraints

- Keep account-management behavior unchanged.
- Prefer native SwiftUI/AppKit patterns already used in the app.
- No new dependencies.
- Preserve localization and menu-bar launch behavior.

## Plan

1. Replace the crowded multi-panel account window with a simpler single-column settings-style layout.
2. Split content into clearer groups: header controls, current account, warning settings, and managed accounts.
3. Replace the plain disabled-text menu summary with a hosted custom overview card while keeping menu actions native.
4. Add or update presentation tests for the new menu summary model.
5. Verify with `swift build`, `swift test`, and a rebuilt `CodeRelay.app`.

## Verification

- `swift build`
- `swift test`
- `zsh ./scripts/build_macos_release.sh`
