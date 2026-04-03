# Quick Task 260402-pus

## Scope

Add a production macOS release path for CodeRelay that uses Developer ID signing, notarization, and stapling so distributed builds no longer trigger Gatekeeper trash warnings on other Macs.

## Constraints

- Keep the existing local ad-hoc packaging flow available for quick internal builds.
- Reuse native Apple tooling already present on macOS (`codesign`, `pkgbuild`, `notarytool`, `stapler`).
- Do not add dependencies.
- Validate with real signed/notarized artifacts, not only script linting.

## Plan

1. Compare the current CodeRelay scripts against CodexBar’s release flow and isolate the missing signing/notarization steps.
2. Update the build and packaging scripts to support Developer ID signing and notarization through environment-driven release mode.
3. Add a convenience release wrapper for the notarized path and document the required credentials.
4. Build a new signed/notarized release, validate it locally, then publish the new GitHub prerelease.

## Verification

- `zsh ./scripts/sign_and_notarize_macos_release.sh`
- `codesign --verify --deep --strict --verbose=4 dist/CodeRelay.app`
- `spctl --assess --type execute --verbose=4 dist/CodeRelay.app`
- `xcrun stapler validate dist/CodeRelay.app`
