# Quick Task 260402-p8k

## Scope

Fix the startup crash that prevents `CodeRelay.app` from opening after the recent menu bar UI redesign.

## Constraints

- Keep the visual redesign intact.
- Limit the fix to startup-safe menu hosting and related cleanup.
- Do not add dependencies.
- Verify with a rebuilt release app, not only `swift build`.

## Plan

1. Confirm the launch failure from macOS crash diagnostics instead of assuming a signing issue.
2. Remove the recursive menu-hosting sizing path introduced by the custom hosted menu view.
3. Rebuild the app and verify that the process stays alive after launch.
4. Report the concrete log locations the user can use for future launch failures.

## Verification

- `swift build`
- `swift test`
- `zsh ./scripts/build_macos_release.sh`
- `open dist/CodeRelay.app`
