---
phase: 02-usage-monitoring-readiness
verified: 2026-04-01T19:08:57Z
status: human_needed
score: 3/3 must-haves verified
human_verification:
  - test: "Launch the app with multiple managed accounts and inspect the accounts screen"
    expected: "The active row shows 5-hour usage, weekly usage, reset timing, last refresh, source, and status; alternate rows show readiness headroom or unknown/stale/error labels."
    why_human: "Visual hierarchy, copy clarity, and actual SwiftUI rendering cannot be fully verified from static inspection and unit tests."
  - test: "Use real managed CODEX_HOME directories and press Refresh Usage with both valid and invalid account credentials"
    expected: "Valid accounts refresh to fresh managed-home OAuth usage; invalid accounts remain visible with stale, error, or unknown status instead of silently clearing."
    why_human: "This depends on live auth.json/config.toml state and an external usage API."
---

# Phase 2: Usage Monitoring & Readiness Verification Report

**Phase Goal:** Users can trust active-account usage signals and compare alternate-account readiness before any destructive switch action.
**Verified:** 2026-04-01T19:08:57Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | User can check the active account's current 5-hour usage and weekly usage. | ✓ VERIFIED | `AccountsFeature.refresh()` projects cached/live snapshots into rows, `AccountsView` renders `5-hour usage:` and `Weekly usage:` for the active row, and Phase 2 feature/projection tests cover cached load plus refreshed active-row values. |
| 2 | User can check reset timing, last refresh time, and probe-source status, and can refresh on demand without silent failure. | ✓ VERIFIED | `AccountsView` renders `Last refreshed:`, `Source:`, and `Status:` plus reset timing within usage copy; `Refresh Usage` invokes `AccountsFeature.refreshMonitoring()`, which refreshes all managed accounts, persists synthesized stale/error/unknown snapshots, and surfaces a completion message instead of clearing the UI. |
| 3 | User can inspect alternate managed accounts for latest readiness plus remaining headroom or unknown state. | ✓ VERIFIED | `DefaultAccountProjection` derives `AlternateAccountReadiness` from per-account snapshots, `AccountsView` renders `Readiness:` for non-active rows, and tests cover fresh, stale, error, and unknown alternate readiness. |

**Score:** 3/3 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `Sources/CodeRelayCore/ManagedAccountUsageSnapshot.swift` | Typed monitoring snapshot, rate-window, source, status, and readiness models | ✓ VERIFIED | Defines `RateWindow`, `UsageProbeSource`, `UsageProbeStatus`, `ManagedAccountUsageSnapshot`, and `AlternateAccountReadiness`. |
| `Sources/CodeRelayCore/ManagedAccountUsageStore.swift` | Versioned per-account usage snapshot persistence | ✓ VERIFIED | Implements `JSONManagedAccountUsageStore` with list/read/upsert/remove and version checks. |
| `Sources/CodeRelayCore/AccountProjection.swift` | Projection of active usage plus alternate readiness | ✓ VERIFIED | Projects active usage windows/source/status and alternate readiness summaries from snapshot input. |
| `Sources/CodeRelayCodex/CodexUsageFetcher.swift` | Managed-home OAuth usage fetch and normalization | ✓ VERIFIED | Reads scoped `auth.json`, optional `config.toml`, calls the usage endpoint, and normalizes 5-hour and weekly windows. |
| `Sources/CodeRelayCodex/CodexUsageRefreshService.swift` | Typed single-account refresh result with stale/error/unknown fallback | ✓ VERIFIED | Wraps the fetcher and preserves truthful degraded states when refresh fails. |
| `Sources/CodeRelayApp/AppContainer.swift` | App wiring for usage store and refresh service | ✓ VERIFIED | Injects `managedAccountUsageStore` and `codexUsageRefreshService` into the live app container. |
| `Sources/CodeRelayApp/Accounts/AccountsFeature.swift` | Cached load, refresh orchestration, persistence, and re-projection | ✓ VERIFIED | Loads cached snapshots at startup and on refresh, refreshes all accounts in deterministic order, persists results, and reprojects rows. |
| `Sources/CodeRelayApp/Accounts/AccountsView.swift` | User-visible monitoring and readiness UI | ✓ VERIFIED | Renders active-account monitoring fields, alternate readiness, and a `Refresh Usage` action. |
| `Tests/CodeRelayCoreTests/ManagedAccountUsageStoreTests.swift` | Store persistence coverage | ✓ VERIFIED | Covers round-trip persistence, version rejection, replace-by-account-id, and missing-account reads. |
| `Tests/CodeRelayCoreTests/AccountProjectionTests.swift` | Projection coverage | ✓ VERIFIED | Covers active usage, alternate readiness, unknown state, and Phase 1 active/live correction preservation. |
| `Tests/CodeRelayCodexTests/CodexUsageFetcherTests.swift` | Managed-home fetcher coverage | ✓ VERIFIED | Covers request construction, auth parsing variants, normalization, and failure handling. |
| `Tests/CodeRelayCodexTests/CodexUsageRefreshServiceTests.swift` | Refresh fallback coverage | ✓ VERIFIED | Covers fresh, stale, unknown, and error results. |
| `Tests/CodeRelayAppTests/AccountsFeatureTests.swift` | Feature-level monitoring coverage | ✓ VERIFIED | Covers cached load, full-account refresh, stale/error preservation, unknown readiness, and required view copy. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Sources/CodeRelayCore/ManagedAccountUsageStore.swift` | `Sources/CodeRelayCore/CodeRelayPaths.swift` | usage cache path resolution | ✓ WIRED | `JSONManagedAccountUsageStore` resolves `paths.managedAccountUsageStoreURL`. |
| `Sources/CodeRelayCore/AccountProjection.swift` | `Sources/CodeRelayCore/ManagedAccountUsageSnapshot.swift` | typed monitoring and readiness projection | ✓ WIRED | Projection consumes `ManagedAccountUsageSnapshot` and `RateWindow` values. |
| `Sources/CodeRelayCore/AccountProjection.swift` | `Sources/CodeRelayCore/ManagedAccount.swift` | managed account identity to readiness row mapping | ✓ WIRED | Projection maps `ManagedAccount` identity/support state into rows. |
| `Sources/CodeRelayCodex/CodexUsageFetcher.swift` | `Sources/CodeRelayCodex/CodexHomeScope.swift` | managed-home auth.json and config.toml resolution | ✓ WIRED | Fetcher reads `scope.authFileURL` and `scope.configFileURL`. |
| `Sources/CodeRelayCodex/CodexUsageFetcher.swift` | `Sources/CodeRelayCore/ManagedAccountUsageSnapshot.swift` | normalized monitoring snapshot output | ✓ WIRED | Fetcher returns normalized `ManagedAccountUsageSnapshot` output. |
| `Sources/CodeRelayCodex/CodexUsageRefreshService.swift` | `Sources/CodeRelayCodex/CodexUsageFetcher.swift` | refresh orchestration and stale fallback mapping | ✓ WIRED | Refresh service calls the fetcher and maps failure types to `.stale`, `.unknown`, or `.error`. |
| `Sources/CodeRelayApp/AppContainer.swift` | `Sources/CodeRelayCore/ManagedAccountUsageStore.swift` | usage-cache service wiring | ✓ WIRED | Container constructs `JSONManagedAccountUsageStore` for the live app. |
| `Sources/CodeRelayApp/Accounts/AccountsFeature.swift` | `Sources/CodeRelayCodex/CodexUsageRefreshService.swift` | manual refresh orchestration | ✓ WIRED | `refreshMonitoring()` calls `codexUsageRefreshService.refresh(account:cachedSnapshot:)`. |
| `Sources/CodeRelayApp/Accounts/AccountsView.swift` | `Sources/CodeRelayApp/Accounts/AccountsFeature.swift` | Refresh Usage button and monitoring row rendering | ✓ WIRED | The view triggers `.refreshMonitoring` and renders projected monitoring fields from feature state. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `Sources/CodeRelayApp/Accounts/AccountsView.swift` | `row.fiveHourWindow`, `row.weeklyWindow`, `row.alternateReadiness` | `AccountsFeature.state.rows` | Yes | ✓ FLOWING |
| `Sources/CodeRelayApp/Accounts/AccountsFeature.swift` | `state.rows` | `managedAccountUsageStore.listSnapshots()` plus `codexUsageRefreshService.refresh(...)`, then `accountProjection.project(...)` | Yes | ✓ FLOWING |
| `Sources/CodeRelayCore/AccountProjection.swift` | `AccountProjectionRow` monitoring fields | `usageSnapshots[account.id]` supplied by the feature | Yes | ✓ FLOWING |
| `Sources/CodeRelayCodex/CodexUsageFetcher.swift` | `ManagedAccountUsageSnapshot.fiveHourWindow` and `weeklyWindow` | Managed account `auth.json` and optional `config.toml`, followed by `GET .../wham/usage` or `.../api/codex/usage` | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase 2 monitoring tests pass | `cd CodeRelay && swift test --filter Phase2` | 23 tests in 5 suites passed | ✓ PASS |
| Full regression suite passes | `cd CodeRelay && swift test` | 41 tests in 8 suites passed | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `MON-01` | `02-01`, `02-02`, `02-03` | User can view the current 5-hour sliding-window usage for the active Codex account. | ✓ SATISFIED | Fetcher normalizes the primary window, projection attaches it to the active row, and `AccountsView` renders `5-hour usage:` for the active account. |
| `MON-02` | `02-01`, `02-02`, `02-03` | User can view the current weekly usage for the active Codex account. | ✓ SATISFIED | Fetcher normalizes the secondary window, projection carries it, and `AccountsView` renders `Weekly usage:` for the active account. |
| `MON-03` | `02-01`, `02-02`, `02-03` | User can view reset timing, last refresh time, and data-source status for the active Codex account. | ✓ SATISFIED | Snapshots store `updatedAt`, source, status, and reset timing; projection and view expose `Last refreshed:`, `Source:`, `Status:`, and reset-aware usage copy. |
| `MON-04` | `02-02`, `02-03` | User can manually refresh account usage and see stale or error states instead of silent failure. | ✓ SATISFIED | `Refresh Usage` triggers per-account refresh, the refresh service maps failures to stale/unknown/error states, and the feature persists/statuses them instead of clearing rows. |
| `MON-05` | `02-01`, `02-02`, `02-03` | User can inspect alternate managed accounts with latest known readiness state and remaining headroom or unknown status. | ✓ SATISFIED | Projection derives `AlternateAccountReadiness` and the view renders headroom or fallback `unknown`/`stale`/`error` labels for non-active rows. |

No orphaned Phase 2 requirements were found. `REQUIREMENTS.md` maps only `MON-01` through `MON-05` to Phase 2, and all five IDs appear in Phase 02 plan frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `—` | `—` | No actionable TODO/FIXME/placeholders, stub returns, or hollow data paths found in Phase 2 implementation files. Broad grep matches were limited to benign initial empty collections and test scaffolding. | ℹ️ Info | No blocker or warning-level anti-patterns identified. |

### Human Verification Required

### 1. Accounts Surface Visual Pass

**Test:** Launch CodeRelay with at least two managed accounts and inspect the accounts screen.
**Expected:** The active row shows 5-hour usage, weekly usage, reset timing, last refresh, source, and status. Alternate rows show readiness headroom or `unknown`/`stale`/`error` labels without exposing warning or switch UI.
**Why human:** Visual hierarchy, readability, and copy clarity need a human look at the rendered SwiftUI interface.

### 2. Live Managed-Home Refresh Pass

**Test:** Prepare real managed `CODEX_HOME` directories, then press `Refresh Usage` once with valid credentials and once with missing/invalid credentials.
**Expected:** Valid accounts return fresh managed-home OAuth usage. Missing or broken credentials leave rows visible with truthful `stale`, `error`, or `unknown` state instead of silent clearing.
**Why human:** This depends on live account state and an external usage API, which static verification and unit tests cannot fully exercise.

### Gaps Summary

No automated implementation gaps were found. The remaining boundary is human-only verification of live managed-account refresh behavior and the final readability of the rendered monitoring UI, so this phase is marked `human_needed` rather than `passed`.

---

_Verified: 2026-04-01T19:08:57Z_
_Verifier: Claude (gsd-verifier)_
