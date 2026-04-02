# Quick Task 260402-obx

## Scope

Refactor the CodeRelay account-management window into a cleaner, modular macOS layout with stronger hierarchy while preserving existing behavior, actions, bindings, and localization keys wherever possible.

## Constraints

- Keep the change presentation-focused.
- Do not change account-management business logic.
- Do not add dependencies.
- Respect the current SwiftUI + AppKit bridge architecture.

## Plan

1. Preserve the existing state/action wiring and feature behavior as-is.
2. Rebuild `AccountsView` around distinct modules:
   - header / global controls
   - focus rail for current account + warning settings
   - account list area with stronger card hierarchy
3. Expand the management window's initial size so the new grouping has enough breathing room.
4. Verify with `swift build` and targeted `swift test`.

## Verification

- `swift build`
- `swift test --filter AccountsFeatureTests`
