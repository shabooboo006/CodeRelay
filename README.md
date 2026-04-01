# CodeRelay

CodeRelay is a macOS Codex companion app for managing multiple managed Codex accounts and, over time, helping users monitor usage and switch accounts safely.

## Current Scope

- Phase 1 code is implemented: managed account add/list/set-active/re-auth/remove and switch-support visibility
- Phase 2 is planned but not implemented yet
- Codex App lifecycle automation is explicitly deferred

## Build

```bash
swift build
swift test
```

## macOS Release Artifacts

Build the release app bundle plus downloadable artifacts:

```bash
zsh ./scripts/package_macos_release.sh
```

Outputs land in `dist/`:

- `CodeRelay.app`
- `CodeRelay-macOS.zip`
- `CodeRelay.pkg`
- `CodeRelay.dmg`

By default the packaging is unsigned/ad-hoc signed unless you add a proper Developer ID signing/notarization flow.
