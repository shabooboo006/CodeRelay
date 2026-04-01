# Roadmap: CodeRelay

## Overview

CodeRelay ships the Codex-only CLI continuity loop first: managed accounts, trustworthy usage monitoring, threshold warnings, safe confirmed switching, and CodeRelay-managed CLI handoff. Codex App lifecycle automation stays outside the v1 critical path and is isolated as a later technical-validation phase once the CLI flow is trustworthy.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Managed Account Foundation** - Establish safe Codex-only account enrollment, storage, identity, and active-account control.
- [ ] **Phase 2: Usage Monitoring & Readiness** - Make active-account usage and alternate-account readiness trustworthy before any switching.
- [ ] **Phase 3: Threshold Warnings** - Warn early with source-aware risk signals and alternate-account suggestions.
- [ ] **Phase 4: Safe Account Switch Transactions** - Deliver confirmed, rollback-safe account switching with verified post-switch state.
- [ ] **Phase 5: CLI Relaunch & Continuity UX** - Close the loop for CodeRelay-managed CLI restart, resume, and recovery surfaces.
- [ ] **Phase 6: Codex App Lifecycle Validation** - Validate Codex App close/relaunch/resume as a later non-v1 track.

## Phase Details

### Phase 1: Managed Account Foundation
**Goal**: Users can safely register and maintain managed Codex accounts with explicit active-account control and unsupported-state visibility.
**Depends on**: Nothing (first phase)
**Requirements**: ACCT-01, ACCT-02, ACCT-03, ACCT-04, ACCT-05, ACCT-06
**Success Criteria** (what must be TRUE):
  1. User can add a Codex account through a scoped login flow and it is stored as a separate managed account.
  2. User can review each managed account's identity, last authentication time, live/active state, and switching-support status.
  3. User can choose which managed account is active, re-authenticate an existing account without duplication, and remove an account no longer needed.
  4. User can tell which managed accounts are safe candidates for later one-click switching before switch automation is enabled.
**Plans**: 3 plans
Plans:
- [x] `01-01-PLAN.md` — Bootstrap the Swift package, Phase 1 contracts, and Wave 0 test scaffolds.
- [x] `01-02-PLAN.md` — Implement the core managed-account registry, projection logic, and bounded removal safety.
- [x] `01-03-PLAN.md` — Implement scoped Codex enrollment/support detection and the thin account-management feature.
**Verification:** Implementation landed, but automated Swift verification is blocked locally by a broken CLT/Xcode toolchain. See `01-VERIFICATION.md`.

### Phase 2: Usage Monitoring & Readiness
**Goal**: Users can trust active-account usage signals and compare alternate-account readiness before any destructive switch action.
**Depends on**: Phase 1
**Requirements**: MON-01, MON-02, MON-03, MON-04, MON-05
**Success Criteria** (what must be TRUE):
  1. User can check the active account's current 5-hour usage and weekly usage.
  2. User can check reset timing, last refresh time, and probe-source status, and can refresh on demand without silent failure.
  3. User can inspect alternate managed accounts for latest readiness plus remaining headroom or unknown state.
**Plans**: TBD

### Phase 3: Threshold Warnings
**Goal**: Users get early, actionable warnings when an active account approaches exhaustion without losing control of when to switch.
**Depends on**: Phase 2
**Requirements**: WARN-01, WARN-02, WARN-03, WARN-04
**Success Criteria** (what must be TRUE):
  1. User can set a low-usage warning threshold as a percentage value.
  2. User receives a local warning when the active account crosses that threshold.
  3. Warning messaging explains whether the risk comes from the 5-hour window, weekly window, both, or stale data.
  4. Warning messaging suggests alternate managed accounts but does not switch accounts automatically.
**Plans**: TBD

### Phase 4: Safe Account Switch Transactions
**Goal**: Users can deliberately move to another managed account through a journaled, rollback-safe switch that leaves the environment in a verified state.
**Depends on**: Phase 3
**Requirements**: SWCH-01, SWCH-02, SWCH-03
**Success Criteria** (what must be TRUE):
  1. User can choose a target managed account from the warning flow or account-management flow and must explicitly confirm before switching.
  2. If any switch step fails, CodeRelay restores the prior state from backup and reports the failure instead of leaving a partial switch behind.
  3. After a successful switch, CodeRelay re-checks account identity and usage so the target account is shown as active with verified freshness.
**Plans**: TBD

### Phase 5: CLI Relaunch & Continuity UX
**Goal**: Users can hand off a CodeRelay-managed Codex CLI session to the newly selected account and keep working with clear recovery details.
**Depends on**: Phase 4
**Requirements**: SWCH-04, SWCH-05, CONT-01, CONT-02, CONT-03, UI-01, UI-02
**Success Criteria** (what must be TRUE):
  1. User can access account health, warnings, and switch actions from a lightweight menu bar surface and open a detailed settings surface for accounts, thresholds, refresh state, and recent switch outcomes.
  2. When the current Codex CLI session is CodeRelay-managed, user can switch accounts and have that CLI workflow closed and relaunched under the target account.
  3. When the current CLI session is not safely controllable, user gets a guided relaunch path instead of CodeRelay killing unrelated terminal processes.
  4. When an explicit session ID exists, CodeRelay attempts `codex resume <session-id>` after relaunch; if resume is unavailable or fails, user still gets the working directory, session context, and fallback command needed to continue manually.
  5. User can inspect a handoff record showing account, timestamp, working directory, and resume candidate after each switch.
**Plans**: TBD
**UI hint**: yes

### Phase 6: Codex App Lifecycle Validation
**Goal**: Codex App lifecycle automation is validated as a later, non-blocking follow-on once CLI continuity is trustworthy.
**Depends on**: Phase 5
**Requirements**: APP-01, APP-02, APP-03
**Success Criteria** (what must be TRUE):
  1. User can have a supported Codex App session detected and explicitly closed before an account switch.
  2. User can relaunch Codex App under the selected managed account after the switch.
  3. When the validated path is reliable, user can resume the prior Codex App conversation after switching.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Managed Account Foundation | 3/3 | Verification blocked | - |
| 2. Usage Monitoring & Readiness | 0/TBD | Not started | - |
| 3. Threshold Warnings | 0/TBD | Not started | - |
| 4. Safe Account Switch Transactions | 0/TBD | Not started | - |
| 5. CLI Relaunch & Continuity UX | 0/TBD | Not started | - |
| 6. Codex App Lifecycle Validation | 0/TBD | Not started | - |
