# Quick Task 260402-pcd

## Scope

Change the default low-usage warning threshold from 20 percent to 5 percent.

## Constraints

- Keep the change limited to default preference behavior.
- Do not change warning evaluation logic or persistence formats.
- Do not add dependencies.

## Plan

1. Update the shared default threshold constant in `WarningPreferences`.
2. Tighten the default-preferences test so it explicitly asserts the new 5 percent default.
3. Verify with a build and targeted tests.

## Verification

- `swift build`
- `swift test --filter WarningPreferencesStoreTests`
