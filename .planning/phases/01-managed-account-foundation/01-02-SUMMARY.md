---
phase: 01-managed-account-foundation
plan: "02"
subsystem: auth
tags: [swift, json, persistence, projection, filesystem]
requires:
  - phase: 01
    provides: package seams and core type contracts
provides:
  - JSON-backed managed account registry with versioning and atomic writes
  - Re-auth deduplication keyed by explicit id or normalized managed envelope
  - Active/live projection and root-bounded managed-home deletion safety
affects: [phase-01-ui, phase-02, phase-04]
tech-stack:
  added: [Foundation JSONEncoder/Decoder]
  patterns: [versioned registry, corrected active selection, root-bounded deletion]
key-files:
  created:
    - Sources/CodeRelayCore/ManagedAccountStore.swift
    - Sources/CodeRelayCore/AccountProjection.swift
    - Sources/CodeRelayCore/ManagedHomeSafety.swift
    - Tests/CodeRelayCoreTests/ManagedAccountStoreTests.swift
    - Tests/CodeRelayCoreTests/AccountProjectionTests.swift
    - Tests/CodeRelayCoreTests/ManagedHomeSafetyTests.swift
  modified: []
key-decisions:
  - "Persist accounts in versioned JSON instead of adding a database dependency."
  - "Correct dangling active selections to nil or the live account match."
patterns-established:
  - "Managed account re-auth reuses the existing row when id or normalized envelope matches."
  - "Deletion safety resolves canonical paths under the managed homes root before removing anything."
requirements-completed: [ACCT-01, ACCT-03, ACCT-04, ACCT-05]
duration: 26min
completed: 2026-04-01
---

# Phase 1: Managed Account Foundation Summary

**Versioned JSON managed-account storage with deduplicating re-authentication, active/live projection, and root-bounded managed-home safety**

## Performance

- **Duration:** 26 min
- **Started:** 2026-04-01T16:31:29Z
- **Completed:** 2026-04-01T16:57:10Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Implemented a JSON registry that references `managed-codex-accounts.json`, writes atomically, and applies secure file permissions.
- Added re-auth update rules that prefer explicit account ids and then normalized email plus managed-home path.
- Implemented projection logic for `isActive`, `isLive`, support state, and corrected active selections, plus safe managed-home deletion checks.

## Task Commits

Implementation landed in one consolidated execution commit because the local SwiftPM toolchain could not support incremental build verification.

1. **Task 1: Implement the JSON managed-account registry and re-auth update flow** - `bac79ba` (`feat(01): implement managed account foundation`)
2. **Task 2: Implement active/live projection and managed-home removal safety** - `bac79ba` (`feat(01): implement managed account foundation`)

## Files Created/Modified
- `Sources/CodeRelayCore/ManagedAccountStore.swift` - Stores accounts in a versioned JSON registry and updates rows in-place on re-auth.
- `Sources/CodeRelayCore/AccountProjection.swift` - Produces Phase 1 account rows and repairs dangling active selections.
- `Sources/CodeRelayCore/ManagedHomeSafety.swift` - Rejects deletions outside the managed account root.
- `Tests/CodeRelayCoreTests/ManagedAccountStoreTests.swift` - Covers round-trip persistence, duplicate suppression, explicit-id re-auth, and unsupported versions.
- `Tests/CodeRelayCoreTests/AccountProjectionTests.swift` - Covers active/live/support-state projection and selection correction.
- `Tests/CodeRelayCoreTests/ManagedHomeSafetyTests.swift` - Covers in-root acceptance and out-of-root rejection.

## Decisions Made
- Kept the managed-account registry file-backed and versioned so it mirrors the actual runtime artifacts.
- Chose nil-or-live-match correction for dangling active ids instead of leaving inconsistent state behind.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Completed registry and projection work without executable Swift validation**
- **Found during:** Task 1 and Task 2
- **Issue:** The machine-level Swift toolchain mismatch prevented `swift test` from running.
- **Fix:** Completed the core implementation and real tests, then documented the verification blocker in phase artifacts.
- **Files modified:** `Sources/CodeRelayCore/*`, `Tests/CodeRelayCoreTests/*`
- **Verification:** Static review of artifact presence, path constants, and requirement-specific code paths
- **Committed in:** `bac79ba`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Core behavior is implemented, but automated execution remains blocked by the local toolchain.

## Issues Encountered
- The environment could not execute `swift test`, so the new tests could only be reviewed statically.

## User Setup Required

None in repo contents, but the local Swift/Xcode installation must be repaired before these tests can run.

## Next Phase Readiness
- The app layer can now rely on durable storage, projection, and safe removal primitives.
- Switch automation should build on this store instead of touching ambient Codex state directly.

---
*Phase: 01-managed-account-foundation*
*Completed: 2026-04-01*
