---
status: testing
phase: 01-managed-account-foundation
source: [01-01-SUMMARY.md, 01-02-SUMMARY.md, 01-03-SUMMARY.md]
started: 2026-04-01T17:04:13Z
updated: 2026-04-01T17:04:13Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 1
name: Launch Account Management Surface
expected: |
  Open CodeRelay. The app should show a managed-account screen with an Add Account action and an account list area or empty state.
  Phase 1 should not expose usage monitoring, warning thresholds, one-click switching, relaunch controls, or resume controls yet.
awaiting: user response

## Tests

### 1. Launch Account Management Surface
expected: Open CodeRelay. The app should show a managed-account screen with an Add Account action and an account list area or empty state. Phase 1 should not expose usage monitoring, warning thresholds, one-click switching, relaunch controls, or resume controls yet.
result: [pending]

### 2. Add Managed Account
expected: Trigger Add Account and complete one managed Codex login. After login returns, exactly one managed account row should appear with recognizable account identity and account metadata instead of staying empty.
result: [pending]

### 3. Inspect Support-State Label
expected: Each managed account row should show one support-state label that makes the account status understandable, such as Supported, Unsupported, or Unverified.
result: [pending]

### 4. Set Active Account
expected: Choosing Set Active on a managed account should mark that row as active and remove the active marker from any previously active managed row.
result: [pending]

### 5. Re-authenticate Existing Account
expected: Re-authenticating an existing managed account should refresh that same row instead of creating a duplicate account entry.
result: [pending]

### 6. Persist Active Selection Across Reopen
expected: After closing and reopening CodeRelay, the previously selected active managed account should still appear as the active row if it still exists.
result: [pending]

### 7. Remove Managed Account
expected: Removing a managed account should delete its row from the list. If the removed account was active, the UI should not leave behind a dangling active marker.
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps

[none yet]
