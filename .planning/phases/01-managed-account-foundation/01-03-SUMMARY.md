---
phase: 01-managed-account-foundation
plan: "03"
subsystem: ui
tags: [swiftui, codex, auth-json, config-toml, macos]
requires:
  - phase: 01
    provides: package seams and core account services
provides:
  - Scoped Codex login flow rooted in managed CODEX_HOME directories
  - Managed-home identity reading and credential storage classification
  - Thin account-management feature and SwiftUI surface for add/set-active/re-auth/remove
affects: [phase-02, phase-03, phase-04, phase-05]
tech-stack:
  added: [SwiftUI, Combine, Process]
  patterns: [managed config persistence, auth.json identity parsing, thin observable feature]
key-files:
  created:
    - Sources/CodeRelayCodex/CodexHomeScope.swift
    - Sources/CodeRelayCodex/CodexIdentityReader.swift
    - Sources/CodeRelayCodex/CredentialStoreDetector.swift
    - Sources/CodeRelayApp/Accounts/AccountsFeature.swift
    - Sources/CodeRelayApp/Accounts/AccountsView.swift
  modified:
    - Sources/CodeRelayApp/AppContainer.swift
    - Sources/CodeRelayApp/CodeRelayApp.swift
key-decisions:
  - "Persist `cli_auth_credentials_store = \"file\"` into each managed home config before login."
  - "Keep the Phase 1 UI limited to account management, not warnings or switching."
patterns-established:
  - "Every managed login gets a scoped CODEX_HOME and never reads ambient ~/.codex for identity."
  - "The app feature persists one active account key and reconciles it through projection."
requirements-completed: [ACCT-01, ACCT-02, ACCT-03, ACCT-04, ACCT-05, ACCT-06]
duration: 26min
completed: 2026-04-01
---

# Phase 1: Managed Account Foundation Summary

**Scoped `codex login` enrollment, managed-home identity/support detection, and a minimal SwiftUI account-management surface for Phase 1**

## Performance

- **Duration:** 26 min
- **Started:** 2026-04-01T16:31:29Z
- **Completed:** 2026-04-01T16:57:10Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Added managed-home scoping utilities and a real `codex login` runner that sets `CODEX_HOME` and persists file-backed auth config.
- Implemented `auth.json` identity parsing plus support-state detection for file, keyring, auto, and unknown credential modes.
- Built the first account-management feature and SwiftUI surface for add, set-active, re-authenticate, and remove actions.

## Task Commits

Implementation landed in one consolidated execution commit because the local SwiftPM toolchain could not support incremental build verification.

1. **Task 1: Implement scoped Codex enrollment, re-authentication, and support-state detection** - `bac79ba` (`feat(01): implement managed account foundation`)
2. **Task 2: Implement the Phase 1 account-management feature and app wiring** - `bac79ba` (`feat(01): implement managed account foundation`)

## Files Created/Modified
- `Sources/CodeRelayCodex/CodexHomeScope.swift` - Defines scoped and ambient Codex home resolution.
- `Sources/CodeRelayCodex/CodexLoginRunner.swift` - Launches `codex login` with managed `CODEX_HOME` and persisted file-backed config.
- `Sources/CodeRelayCodex/CodexIdentityReader.swift` - Reads account identity from managed-home `auth.json`.
- `Sources/CodeRelayCodex/CredentialStoreDetector.swift` - Classifies managed accounts as supported, unsupported, or unverified.
- `Sources/CodeRelayApp/Accounts/AccountsFeature.swift` - Coordinates add, set-active, re-authenticate, remove, and projection refresh.
- `Sources/CodeRelayApp/Accounts/AccountsView.swift` - Renders the Phase 1 account-management surface.

## Decisions Made
- Wrote managed-home `config.toml` files explicitly so support-state classification can reason about credential storage mode later.
- Kept the visible UI surface limited to account management and support-state visibility; no warnings, relaunch, or switch orchestration were introduced.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Stabilized app wiring and Codex integration without runnable Swift validation**
- **Found during:** Task 1 and Task 2
- **Issue:** `swift build` / `swift test` were blocked by the local SDK/toolchain mismatch before code verification could start.
- **Fix:** Completed the UI and Codex integration, then documented the environment blocker in the verification artifact instead of silently claiming green checks.
- **Files modified:** `Sources/CodeRelayCodex/*`, `Sources/CodeRelayApp/*`, `Tests/CodeRelayCodexTests/*`, `Tests/CodeRelayAppTests/*`
- **Verification:** Static review of scoped `CODEX_HOME`, file-backed config persistence, support-state branches, and account action routing
- **Committed in:** `bac79ba`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The user-facing Phase 1 slice exists, but automated execution still depends on fixing the local Swift toolchain.

## Issues Encountered
- The local machine has no full Xcode and its Command Line Tools cannot compile even a fresh Swift package, so runtime verification is still blocked outside the repo.

## User Setup Required

Before testing the add/re-auth flow against a real Codex account, install/select a matching Swift/Xcode toolchain so `swift build` and `swift test` work locally.

## Next Phase Readiness
- Phase 2 can now build usage monitoring on top of the managed-account registry and active account key.
- Future switch automation can use the support-state labels to avoid pretending unsupported accounts are safe.

---
*Phase: 01-managed-account-foundation*
*Completed: 2026-04-01*
