---
phase: 01-managed-account-foundation
verified: 2026-04-01T16:57:10Z
status: gaps_found
score: 3/4 must-haves verified
---

# Phase 1: Managed Account Foundation Verification Report

**Phase Goal:** Users can safely register and maintain managed Codex accounts with explicit active-account control and unsupported-state visibility.
**Verified:** 2026-04-01T16:57:10Z
**Status:** gaps_found

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can add a Codex account through a scoped login flow and it is stored as a separate managed account. | ? UNCERTAIN | `CodexLoginRunner` scopes `CODEX_HOME` and `AccountsFeature.addAccount()` persists the result, but the real flow could not be executed because local Swift toolchain validation is blocked. |
| 2 | User can review each managed account's identity, last authentication time, live/active state, and switching-support status. | ✓ VERIFIED | `AccountsFeature` projects `rows`; [AccountsView.swift](/Users/xiachy/github-code/code-relay-mono-repo/CodeRelay/Sources/CodeRelayApp/Accounts/AccountsView.swift) renders email, active/live badges, support label, and last-auth copy. |
| 3 | User can choose which managed account is active, re-authenticate an existing account without duplication, and remove an account no longer needed. | ✓ VERIFIED | `AccountsFeature` implements `.setActive`, `.reauthenticate`, and `.remove`; tests in [AccountsFeatureTests.swift](/Users/xiachy/github-code/code-relay-mono-repo/CodeRelay/Tests/CodeRelayAppTests/AccountsFeatureTests.swift) cover active-key persistence, existing-id re-auth routing, and guarded removal. |
| 4 | User can tell which managed accounts are safe candidates for later one-click switching before switch automation is enabled. | ✓ VERIFIED | `CredentialStoreDetector` classifies `.file`, `.keyring`, `.auto`, and `.unknown` into supported / unsupported / unverified support states, and the view surfaces the result. |

**Score:** 3/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Package.swift` | Swift package targets for app/core/codex/tests | ✓ EXISTS + SUBSTANTIVE | Declares `CodeRelayApp`, `CodeRelayCore`, `CodeRelayCodex`, and the three test targets. |
| `Sources/CodeRelayCore/ManagedAccountStore.swift` | Durable JSON registry and re-auth rules | ✓ EXISTS + SUBSTANTIVE | Implements versioned registry load/save, atomic writes, duplicate suppression, and controlled unknown-id failures. |
| `Sources/CodeRelayCodex/CredentialStoreDetector.swift` | Support-state classifier | ✓ EXISTS + SUBSTANTIVE | Parses `config.toml`, checks `auth.json`, and returns only supported / unsupported / unverified. |
| `Sources/CodeRelayApp/Accounts/AccountsView.swift` | Minimal account-management surface | ✓ EXISTS + SUBSTANTIVE | Renders managed account rows with add, set-active, re-authenticate, and remove actions. |

**Artifacts:** 4/4 verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `Sources/CodeRelayCodex/CodexLoginRunner.swift` | `Sources/CodeRelayCodex/CodexHomeScope.swift` | `CODEX_HOME` scoped environment | ✓ WIRED | `login(request:)` builds the environment through `request.scope.environment(...)`. |
| `Sources/CodeRelayApp/AppContainer.swift` | `Sources/CodeRelayCore/ManagedAccountStore.swift` | feature service wiring | ✓ WIRED | `AppContainer.Services` defaults `managedAccountStore` to `JSONManagedAccountStore(...)`. |
| `Sources/CodeRelayApp/Accounts/AccountsFeature.swift` | `Sources/CodeRelayCodex/CredentialStoreDetector.swift` | support-state display and enrollment flow | ✓ WIRED | `addAccount()` and `reauthenticate()` call `detectSupport(in:)` and `credentialStoreMode(in:)`. |

**Wiring:** 3/3 connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| ACCT-01 | ? NEEDS EXECUTION | Real `codex login` flow not executed locally because Swift toolchain/SDK is broken. |
| ACCT-02 | ✓ SATISFIED | - |
| ACCT-03 | ✓ SATISFIED | - |
| ACCT-04 | ✓ SATISFIED | - |
| ACCT-05 | ✓ SATISFIED | - |
| ACCT-06 | ✓ SATISFIED | - |

**Coverage:** 5/6 requirements satisfied

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| Local environment | - | Broken SwiftPM manifest/toolchain linkage | 🛑 Blocker | Prevents `swift build` / `swift test` from verifying the phase automatically |

**Anti-patterns:** 1 found (1 blockers, 0 warnings)

## Human Verification Required

### 1. Managed Enrollment Flow
**Test:** Launch the app, add a managed account, and confirm the new row appears with email, support state, and last-auth timestamp.  
**Expected:** The account is stored under a managed `CODEX_HOME`, appears in the list, and can be set active or re-authenticated.  
**Why human:** The local Swift/Xcode environment cannot build or run the app right now.

## Gaps Summary

### Critical Gaps (Block Progress)

1. **Local Swift toolchain cannot verify the phase**
   - Missing: A working Xcode or Command Line Tools install that matches the installed SDK.
   - Impact: `swift build` and `swift test` fail before project code executes, so ACCT-01 cannot be validated end-to-end.
   - Fix: Install/select a matching Xcode or CLT toolchain, then rerun the Swift build/test commands and the manual add-account flow.

### Non-Critical Gaps (Can Defer)

1. **Visual QA has not been run on the SwiftUI account surface**
   - Issue: The view implementation exists, but the local machine could not launch it.
   - Impact: Layout polish and copy clarity are still unverified.
   - Recommendation: Run the manual account-management flow once the toolchain is repaired.

## Recommended Fix Plans

### 01-04-PLAN.md: Restore Local Swift Verification

**Objective:** Re-enable `swift build` and `swift test` so the implemented Phase 1 code can be verified automatically.

**Tasks:**
1. Repair the local Xcode/Command Line Tools installation and confirm a fresh Swift package builds.
2. Rerun `swift build`, `swift test --filter Phase1`, and `swift test` inside `CodeRelay/`.
3. Launch the Phase 1 app surface and validate the managed account add/re-auth/remove flow manually.

**Estimated scope:** Small

## Verification Metadata

**Verification approach:** Goal-backward (derived from ROADMAP.md Phase 1 goal)  
**Must-haves source:** ROADMAP.md + Phase 1 plan frontmatter  
**Automated checks:** 0 passed, 1 blocked by environment  
**Human checks required:** 1  
**Total verification time:** 12 min

---
*Verified: 2026-04-01T16:57:10Z*
*Verifier: Codex*
