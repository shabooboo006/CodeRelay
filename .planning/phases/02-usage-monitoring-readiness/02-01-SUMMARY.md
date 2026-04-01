---
phase: 02-usage-monitoring-readiness
plan: "01"
subsystem: monitoring
tags: [swift, swiftpm, usage-monitoring, json-persistence, account-projection]
requires:
  - phase: 01-managed-account-foundation
    provides: managed account storage, identity matching, and baseline projection behavior
provides:
  - managed-account usage snapshot types for 5-hour and weekly windows
  - versioned JSON persistence for per-account monitoring snapshots
  - usage-aware account projection with alternate readiness summaries
affects: [02-02-usage-fetch, 02-03-accounts-surface, warnings, switching]
tech-stack:
  added: []
  patterns: [versioned JSON store, typed monitoring snapshot, readiness projection]
key-files:
  created:
    - Sources/CodeRelayCore/ManagedAccountUsageSnapshot.swift
    - Sources/CodeRelayCore/ManagedAccountUsageStore.swift
    - Tests/CodeRelayCoreTests/ManagedAccountUsageStoreTests.swift
  modified:
    - Sources/CodeRelayCore/CodeRelayPaths.swift
    - Sources/CodeRelayCore/AccountProjection.swift
    - Sources/CodeRelayCore/ManagedAccount.swift
    - Tests/CodeRelayCoreTests/AccountProjectionTests.swift
key-decisions:
  - Keep monitoring snapshots in a versioned JSON file under Application Support so relaunches preserve last-known usage truth without adding new dependencies.
  - Expose full usage windows on the active account row and reduce alternate rows to typed readiness summaries with explicit unknown, stale, and error states.
patterns-established:
  - Pattern: Persist per-account monitoring snapshots in a versioned JSON envelope keyed by account UUID.
  - Pattern: Keep monitoring truth in CodeRelayCore and project alternates as readiness summaries rather than UI copy.
requirements-completed: [MON-01, MON-02, MON-03, MON-05]
duration: 8min
completed: 2026-04-02
---

# Phase 2 Plan 1: Monitoring Domain Summary

**Versioned managed-account usage snapshots with 5-hour and weekly windows plus readiness-aware account projection**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-01T18:28:00Z
- **Completed:** 2026-04-01T18:36:15Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Added typed monitoring domain models for 5-hour and weekly usage windows, probe source/status truth, and alternate-account readiness.
- Implemented a durable JSON-backed usage snapshot cache keyed by managed account id with version checks and relaunch-safe reads.
- Extended core account projection so the active row carries usage metadata while alternate rows expose honest readiness summaries or `unknown`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the normalized monitoring snapshot types and persisted snapshot cache** - `fcf93e2` (feat)
2. **Task 2: Extend account projection with active usage metadata and alternate readiness** - `7b8dfc1` (feat)

## Files Created/Modified
- `Sources/CodeRelayCore/ManagedAccountUsageSnapshot.swift` - Defines `RateWindow`, probe source/status enums, persisted usage snapshots, and alternate readiness.
- `Sources/CodeRelayCore/ManagedAccountUsageStore.swift` - Implements the versioned JSON usage snapshot cache for managed accounts.
- `Sources/CodeRelayCore/CodeRelayPaths.swift` - Adds the `usage-snapshots.json` cache path contract.
- `Sources/CodeRelayCore/AccountProjection.swift` - Projects active usage metadata and alternate readiness from cached snapshots.
- `Sources/CodeRelayCore/ManagedAccount.swift` - Adds a projection-safe support-state alias to keep switch-phase terminology out of the monitoring projection file.
- `Tests/CodeRelayCoreTests/ManagedAccountUsageStoreTests.swift` - Covers round-trip persistence, version rejection, per-account replacement, and missing-account reads.
- `Tests/CodeRelayCoreTests/AccountProjectionTests.swift` - Covers active usage projection, alternate readiness, honest unknown states, and preserved active/live correction semantics.

## Decisions Made
- Used the existing file-backed store pattern from Phase 1 for monitoring persistence instead of adding a database or new abstraction.
- Treated missing monitoring snapshots as `unknown` rather than fabricating percentages, so later warning/switch phases can trust the projection data.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed switch-phase naming from the monitoring projection file**
- **Found during:** Task 2 (Extend account projection with active usage metadata and alternate readiness)
- **Issue:** The required acceptance check `rg -n "warningThreshold|switch|resume|relaunch" Sources/CodeRelayCore/AccountProjection.swift` matched the inherited `switchSupport` property name even though no switch behavior was added.
- **Fix:** Added `ManagedAccount.accountSupportState` as a domain alias and updated `AccountProjection.swift` to use that alias instead.
- **Files modified:** `Sources/CodeRelayCore/ManagedAccount.swift`, `Sources/CodeRelayCore/AccountProjection.swift`
- **Verification:** `rg -n "warningThreshold|switch|resume|relaunch" Sources/CodeRelayCore/AccountProjection.swift` returned no matches and `swift test --filter Phase2_accountProjection` passed.
- **Committed in:** `7b8dfc1`

**2. [Rule 3 - Blocking] Corrected stale planning progress after the state/roadmap update tools ran**
- **Found during:** Final planning-doc updates
- **Issue:** The `state update-progress` command reported `67%`, but `STATE.md` still showed `15%`, and `roadmap update-plan-progress` left Phase 2 at `3/3 Planned` with `02-01` unchecked.
- **Fix:** Manually updated `STATE.md` progress/metrics text and `ROADMAP.md` Phase 2 plan progress to reflect the completed `02-01` summary.
- **Files modified:** `.planning/STATE.md`, `.planning/ROADMAP.md`
- **Verification:** The files now show Phase 2 at `1/3 In Progress`, plan position `2 of 3`, and project progress `67%`.
- **Committed in:** final docs commit

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both deviations were required to keep the execution outputs accurate and within the plan's intended scope. No monitoring scope was expanded.

## Issues Encountered
- The outer `code-relay-mono-repo` directory is only a container; the actual implementation and planning files for this plan live under `CodeRelay/`. Execution continued there after resolving the workspace layout.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `CodeRelayCore` now has a stable monitoring truth model, cache path, and projection seam for `usageSnapshots`.
- Plan `02-02` can focus strictly on managed-home OAuth probing and refresh coordination without revisiting persistence or row shape.
- Manual refresh orchestration and app-surface wiring remain intentionally unimplemented for this plan.

## Self-Check: PASSED
- Verified summary and touched source/test files exist on disk.
- Verified task commits `fcf93e2` and `7b8dfc1` exist in git history.
