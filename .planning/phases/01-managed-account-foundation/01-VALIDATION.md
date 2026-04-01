---
phase: 1
slug: managed-account-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing / `swift test` |
| **Config file** | `Package.swift` |
| **Quick run command** | `swift test --filter Phase1` |
| **Full suite command** | `swift test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter Phase1`
- **After every plan wave:** Run `swift test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | ACCT-01 | unit | `swift test --filter Phase1` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | ACCT-04 | unit | `swift test --filter Phase1` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | ACCT-06 | unit | `swift test --filter Phase1` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | ACCT-02 | integration | `swift test` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 2 | ACCT-03, ACCT-05 | integration | `swift test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/CodeRelayCoreTests/ManagedAccountStoreTests.swift` — store round-trip, versioning, deduplication, re-auth update behavior
- [ ] `Tests/CodeRelayCodexTests/CredentialStoreDetectorTests.swift` — supported / unsupported / unverified classification
- [ ] `Tests/CodeRelayCoreTests/AccountReconcilerTests.swift` — active/live projection and selection correction
- [ ] `Tests/CodeRelayCoreTests/ManagedHomeSafetyTests.swift` — bounded deletion checks for managed-home root
- [ ] `swift package init` / initial test target wiring — if no package structure exists yet

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Account-management surface shows active/live/support state clearly | ACCT-02, ACCT-03, ACCT-06 | Early UI affordance quality is easier to validate visually than with automation only | Open the Phase 1 account screen/menu and verify each account row shows email, auth freshness, active/live state, and support-state label |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
