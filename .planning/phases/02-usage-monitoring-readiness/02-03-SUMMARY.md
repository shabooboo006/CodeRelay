---
phase: 02-usage-monitoring-readiness
plan: "03"
subsystem: ui
tags: [swift, swiftui, codex-monitoring, managed-accounts, tdd]
requires:
  - phase: 02-01
    provides: usage snapshot storage and readiness projection
  - phase: 02-02
    provides: managed-home Codex usage refresh service
provides:
  - AccountsFeature projection now includes cached monitoring state and manual refresh orchestration.
  - AccountsView shows active-account usage metadata and alternate-account readiness in the existing surface.
affects: [warnings, switching, account-management]
tech-stack:
  added: []
  patterns: [cached snapshot projection, deterministic managed-account refresh ordering, truthful stale-error-unknown rendering]
key-files:
  created: []
  modified:
    - Sources/CodeRelayApp/AppContainer.swift
    - Sources/CodeRelayApp/Accounts/AccountsFeature.swift
    - Sources/CodeRelayApp/Accounts/AccountsView.swift
    - Tests/CodeRelayAppTests/AccountsFeatureTests.swift
key-decisions:
  - "Persist synthesized unknown/error snapshots when refresh cannot return usage windows so the UI can render honest state without collapsing rows."
  - "Keep manual refresh messaging scoped to all-fresh success vs stale/error completion instead of introducing warning or switching copy in Phase 2."
patterns-established:
  - "AccountsFeature always reprojects rows from the usage cache, both on startup and after refresh."
  - "AccountsView renders typed monitoring truth from projection rows instead of recomputing readiness in the UI."
requirements-completed: [MON-01, MON-02, MON-03, MON-04, MON-05]
duration: 7min
completed: 2026-04-01
---

# Phase 02 Plan 03: Accounts Monitoring Surface Summary

**Managed-account usage refresh is wired into the accounts feature and rendered in the existing SwiftUI surface with explicit freshness, source, and alternate readiness state.**

## Performance

- **Duration:** 7min
- **Started:** 2026-04-01T18:53:13Z
- **Completed:** 2026-04-01T19:00:47Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Loaded cached usage snapshots into `AccountsFeature` startup and re-projection flow.
- Added deterministic manual refresh across all managed accounts with stale/error fallback preserved in the cache.
- Rendered active-account usage metadata and alternate readiness directly in the current accounts screen with a visible `Refresh Usage` action.

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire cached monitoring load and manual refresh into AccountsFeature** - `efd2dfb` (test), `7e85aa6` (feat)
2. **Task 2: Render active usage, refresh metadata, and alternate readiness in AccountsView** - `faf263c` (test), `04aa70f` (feat)

_Note: TDD tasks used separate test and feature commits._

## Files Created/Modified
- `Sources/CodeRelayApp/AppContainer.swift` - Wires the managed-account usage store and Codex usage refresh service into app services.
- `Sources/CodeRelayApp/Accounts/AccountsFeature.swift` - Loads cached snapshots, adds `refreshMonitoring`, synthesizes truthful fallback snapshots, and reprojects rows after refresh.
- `Sources/CodeRelayApp/Accounts/AccountsView.swift` - Adds the manual refresh button and monitoring/readiness copy inside the existing account cards.
- `Tests/CodeRelayAppTests/AccountsFeatureTests.swift` - Covers cached load, refresh ordering, stale/error/unknown visibility, and required view copy.

## Decisions Made
- Persist unknown and error refresh results as nil-window snapshots so the UI can show honest status/source state even when no prior cache exists.
- Keep the monitoring completion message coarse-grained and monitoring-only to avoid leaking later warning or switching behavior into this phase.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Synthesized unknown/error snapshots when refresh returned no usage windows**
- **Found during:** Task 1 (Wire cached monitoring load and manual refresh into AccountsFeature)
- **Issue:** Without a persisted snapshot for unknown/error refresh results, the projection would fall back to implicit `.unknown` and hide explicit error state for accounts with no cache.
- **Fix:** `AccountsFeature` now materializes nil-window snapshots for non-fresh refresh results so rows remain visible with truthful status, source, timestamp, and readiness state.
- **Files modified:** `Sources/CodeRelayApp/Accounts/AccountsFeature.swift`
- **Verification:** `swift test --filter Phase2_accountsFeature` and `swift test`
- **Committed in:** `7e85aa6`

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Necessary to satisfy the plan’s stale/error/unknown visibility requirement. No scope creep beyond Phase 2 monitoring.

## Issues Encountered
- The provided outer workspace path was a container with multiple repos. Execution was redirected into `CodeRelay/`, which contained the plan, planning state, and implementation targets.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Warning-threshold and switch-selection phases can build on stable active-row usage data, alternate readiness summaries, and a manual refresh affordance already present in the accounts surface.
- The monitoring scope boundary remains intact: no thresholds, warning CTAs, relaunch, resume, or account-switch actions were added here.

## Self-Check: PASSED

- Found `.planning/phases/02-usage-monitoring-readiness/02-03-SUMMARY.md`
- Found commit `efd2dfb`
- Found commit `7e85aa6`
- Found commit `faf263c`
- Found commit `04aa70f`
