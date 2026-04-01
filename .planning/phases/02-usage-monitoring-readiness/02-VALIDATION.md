---
phase: 2
slug: usage-monitoring-readiness
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-02
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing / `swift test` |
| **Config file** | `Package.swift` |
| **Quick run command** | `swift test --filter Phase2` |
| **Full suite command** | `swift test` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter Phase2`
- **After every plan wave:** Run `swift test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | MON-01, MON-02, MON-03 | unit | `swift test --filter Phase2_managedAccountUsageStore` | ✅ | ⬜ pending |
| 02-01-02 | 01 | 1 | MON-05 | unit | `swift test --filter Phase2_accountProjection` | ✅ | ⬜ pending |
| 02-02-01 | 02 | 2 | MON-01, MON-02, MON-03 | integration | `swift test --filter Phase2_codexUsageFetcher` | ✅ | ⬜ pending |
| 02-02-02 | 02 | 2 | MON-03, MON-04, MON-05 | integration | `swift test --filter Phase2_codexUsageRefreshService` | ✅ | ⬜ pending |
| 02-03-01 | 03 | 3 | MON-03, MON-04, MON-05 | integration | `swift test --filter Phase2_accountsFeature` | ✅ | ⬜ pending |
| 02-03-02 | 03 | 3 | MON-01, MON-02, MON-03, MON-05 | integration | `swift test --filter Phase2_accountsFeature` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing Phase 1 SwiftPM and test infrastructure already covers this phase.

- [x] `Package.swift` — SwiftPM target/test wiring exists
- [x] `Tests/CodeRelayCoreTests/` — core unit-test target exists
- [x] `Tests/CodeRelayCodexTests/` — codex integration test target exists
- [x] `Tests/CodeRelayAppTests/` — app feature test target exists

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Active account usage row clearly shows 5-hour usage, weekly usage, last refresh, and source/status copy | MON-01, MON-02, MON-03 | Final copy clarity and visual hierarchy are easier to validate in the running app | Open the account surface, verify the active row shows both windows plus refresh/source text without exposing Phase 3 warning controls |
| Alternate accounts show readiness as remaining headroom or honest unknown/stale/error states | MON-05 | Relative readability across multiple rows is easier to assess visually than via unit tests only | Refresh multiple managed accounts and verify alternates present a scannable readiness summary instead of raw debug data |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
