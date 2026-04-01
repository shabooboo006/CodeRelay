---
phase: 01-managed-account-foundation
verified: 2026-04-01T17:47:49Z
status: human_needed
score: 3/4 must-haves verified
---

# Phase 1: Managed Account Foundation Verification Report

**Phase Goal:** Users can safely register and maintain managed Codex accounts with explicit active-account control and unsupported-state visibility.
**Verified:** 2026-04-01T17:47:49Z
**Status:** human_needed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can add a Codex account through a scoped login flow and it is stored as a separate managed account. | ? HUMAN CHECK | `CodexLoginRunner` scopes `CODEX_HOME` and `AccountsFeature.addAccount()` persists the result, and `swift build` / `swift test` now pass locally. The remaining gap is a real managed login run against a human account. |
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
| ACCT-01 | ? HUMAN CHECK | Real `codex login` flow still needs a manual managed-account enrollment run. |
| ACCT-02 | ✓ SATISFIED | - |
| ACCT-03 | ✓ SATISFIED | - |
| ACCT-04 | ✓ SATISFIED | - |
| ACCT-05 | ✓ SATISFIED | - |
| ACCT-06 | ✓ SATISFIED | - |

**Coverage:** 5/6 requirements satisfied

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| - | - | - | - | No repository anti-pattern blocked automated verification after the Xcode toolchain was repaired. |

**Anti-patterns:** 0 found

## Human Verification Required

### 1. Managed Enrollment Flow
**Test:** Launch the app, add a managed account, and confirm the new row appears with email, support state, and last-auth timestamp.  
**Expected:** The account is stored under a managed `CODEX_HOME`, appears in the list, and can be set active or re-authenticated.  
**Why human:** This requires a real Codex login and account identity that automated tests cannot simulate end-to-end.

## Gaps Summary

### Remaining Gaps

1. **Visual QA and managed enrollment UAT have not been run on the SwiftUI account surface**
   - Issue: The view implementation exists, but the local machine could not launch it.
   - Impact: Layout polish, copy clarity, and the real Codex login handoff are still unverified.
   - Recommendation: Launch the app and complete the Phase 1 UAT flow for add / set-active / re-auth / remove.

## Recommended Fix Plans

### 01-04-PLAN.md: Complete Managed Enrollment UAT

**Objective:** Validate the real managed login flow and visible Phase 1 surface against a live Codex account.

**Tasks:**
1. Launch the app and complete the managed account add flow.
2. Confirm active selection, re-authentication, and removal work against the real managed account row.
3. Record the UAT outcome in `01-UAT.md`.

**Estimated scope:** Small

## Verification Metadata

**Verification approach:** Goal-backward (derived from ROADMAP.md Phase 1 goal)  
**Must-haves source:** ROADMAP.md + Phase 1 plan frontmatter  
**Automated checks:** `swift build` passed; `swift test` passed locally after Xcode 26.4 toolchain repair  
**Human checks required:** 1  
**Total verification time:** 12 min

---
*Verified: 2026-04-01T17:47:49Z*
*Verifier: Codex*
