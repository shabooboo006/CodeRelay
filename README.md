# CodeRelay

[简体中文](README.zh-CN.md)

CodeRelay is a macOS companion app for people who manage more than one Codex account. It keeps each account in its own isolated `CODEX_HOME`, lets you re-authenticate accounts without mixing credentials, shows which accounts look ready based on the latest usage snapshot, and warns when the active account is getting close to exhaustion.

## Status

The current codebase is usable for managed-account enrollment, usage visibility, and threshold warnings, but it is not a full account switcher yet.

Implemented now:

- add a managed account by running `codex login` inside a CodeRelay-owned home directory
- list, re-authenticate, and remove managed accounts
- mark one managed account as the locally selected active account
- read managed-account identity from `auth.json`
- detect whether the managed account is file-backed, keyring-backed, or unverified
- refresh usage snapshots for all managed accounts and surface readiness information in the app UI
- refresh the currently active managed account in the background on a configurable cadence
- configure one global warning threshold plus a notifications toggle
- warn once per depletion cycle when the active account falls below threshold in either tracked window
- surface stale, error, and unknown monitoring risk states in both the management window and menu bar
- use a menu bar icon as the primary post-setup entry point, while keeping first-run enrollment in a dedicated setup window
- localize the app shell in English and Simplified Chinese
- persist account metadata and usage snapshots under `~/Library/Application Support/CodeRelay`

Not implemented yet:

- swapping the live `~/.codex/auth.json` and `~/.codex/config.toml`
- reopening Codex sessions or restoring CLI/App workflows after a switch

## Requirements

- macOS 15.0+
- Swift toolchain with SwiftPM support
- `codex` available on `PATH`

`Add Account` shells out to:

```bash
codex -c 'cli_auth_credentials_store="file"' login
```

That means CodeRelay currently works best with file-backed Codex credentials. Keyring-backed accounts are detected and shown as unsupported for safe file-based switching.

## Build And Run

For local development:

```bash
swift build
swift test
swift run CodeRelayApp
```

## Release Packaging

For a local ad-hoc bundle plus archive formats:

```bash
zsh ./scripts/package_macos_release.sh
```

For a production Developer ID signed + notarized release:

```bash
NOTARYTOOL_PROFILE=CodeRelayNotary \
zsh ./scripts/sign_and_notarize_macos_release.sh
```

That release wrapper produces the GitHub-facing `zip` + `dmg` set by default. If you also need a signed installer package, override `PACKAGE_FORMATS="zip pkg dmg"` explicitly.

Artifacts are written to `dist/`:

- `CodeRelay.app`
- `CodeRelay-<VERSION>-macOS.zip`
- `CodeRelay-<VERSION>.pkg`
- `CodeRelay-<VERSION>.dmg`

Production release prerequisites:

- `Developer ID Application` certificate in your login keychain
- `Developer ID Installer` certificate in your login keychain
- `xcrun notarytool` keychain profile, for example `CodeRelayNotary`

Security note:

- the release scripts read signing identities from your local keychain and read notarization credentials from an existing `notarytool` keychain profile
- no Apple private keys, `.p8` files, exported certificates, or account secrets are stored in this repository or embedded into GitHub release metadata

The local packaging script stays ad-hoc by default. The notarized wrapper script switches signing to Developer ID, submits the app/pkg/dmg to Apple, staples the tickets, and validates the final app with `codesign` and `spctl`.

## How It Works

1. Each managed account gets its own isolated home under `~/Library/Application Support/CodeRelay/managed-codex-homes/<uuid>/`.
2. CodeRelay runs `codex login` with `CODEX_HOME` pointed at that managed home.
3. It reads identity details from the managed `auth.json` and stores account metadata in a local JSON registry.
4. Usage refresh reads the managed account token and calls the Codex usage endpoint, then stores the latest snapshot locally.
5. The UI uses those snapshots to show the selected active account's usage and other accounts' readiness.
6. A runtime-owned scheduler can refresh the active managed account in the background and evaluate warning state after each refresh.
7. Warning state is deduplicated per depletion cycle, so the app does not spam repeated notifications while the active account remains below threshold.
8. After first setup, CodeRelay is primarily opened from the menu bar instead of living as a permanent main window.

The current `Set Active` action only changes CodeRelay's local selection. It does not mutate the live `~/.codex` files yet.

## Local Data

CodeRelay currently stores data here:

- `~/Library/Application Support/CodeRelay/managed-codex-accounts.json`
- `~/Library/Application Support/CodeRelay/usage-snapshots.json`
- `~/Library/Application Support/CodeRelay/managed-codex-homes/<uuid>/`

The JSON stores are written atomically and locked down to `0600` permissions on macOS.

## Project Layout

- `Sources/CodeRelayApp`: SwiftUI app shell and account-management UI
- `Sources/CodeRelayCore`: account models, projection logic, persistence, and filesystem safety checks
- `Sources/CodeRelayCodex`: Codex-specific login, identity, credential-mode detection, and usage refresh logic
- `Tests/CodeRelayAppTests`: UI-facing feature tests
- `Tests/CodeRelayCoreTests`: core model and storage tests
- `Tests/CodeRelayCodexTests`: Codex integration unit tests

## Current Limitations

- macOS only
- depends on the installed `codex` CLI
- no live account switch into `~/.codex` yet
- background refresh only covers the active managed account in this phase
- no automatic session resume yet
