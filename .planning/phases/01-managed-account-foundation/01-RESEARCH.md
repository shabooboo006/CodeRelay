# Phase 1 Research: Managed Account Foundation

**Phase:** 1  
**Researched:** 2026-04-02  
**Status:** Complete  
**Scope:** ACCT-01, ACCT-02, ACCT-03, ACCT-04, ACCT-05, ACCT-06

## Objective

Answer: what needs to be true to plan Phase 1 well?

Phase 1 is the safety-critical base for the rest of CodeRelay. It needs to establish managed Codex account enrollment, durable account identity, active-account selection, re-authentication, removal, and unsupported-state visibility without drifting into switching, warnings, or UI-heavy scope.

## What This Phase Must Establish

1. A durable managed-account registry under app-owned storage
2. A per-account managed `CODEX_HOME` directory model
3. A scoped login and re-authentication flow that does not duplicate accounts
4. A visible account projection that distinguishes:
   - managed accounts
   - the ambient live system account
   - the currently active account inside CodeRelay
5. Early detection of credential-storage modes that make later one-click switching unsafe or unsupported

## Recommended Technical Direction

### 1. Use managed homes as the primary account boundary

Each managed account should own a dedicated directory under:

`~/Library/Application Support/CodeRelay/managed-codex-homes/<account-id>/`

Why:

- This matches the strongest CodexBar pattern.
- It keeps each account's Codex artifacts isolated.
- It avoids inventing a database-first representation for auth/config state.
- It prepares the project for CLI-first relaunch under `CODEX_HOME=<targetManagedHome>` later.

### 2. Keep the account registry file-backed and versioned

Use a versioned JSON file such as:

`~/Library/Application Support/CodeRelay/managed-codex-accounts.json`

Minimum fields per account:

- `id`
- `email`
- `managedHomePath`
- `createdAt`
- `updatedAt`
- `lastAuthenticatedAt`
- `credentialStoreMode`
- `switchSupport`
- `lastValidatedIdentity`

Why:

- It is sufficient for Phase 1.
- It stays consistent with the research direction already chosen for CodeRelay.
- It makes later reconciliation and preflight checks straightforward.

### 3. Treat identity as richer than email alone

Do not use email as the only trust key. Phase 1 should store at least:

- normalized email
- managed home path
- detected credential store mode
- last validation timestamp
- source used for validation

Optional if discoverable:

- workspace or plan metadata exposed by Codex probes

Why:

- The research identified email-only matching as too weak.
- It reduces later confusion when the same email may not imply an identical usable account context.

### 4. Add explicit credential-store compatibility detection now

Phase 1 should detect how Codex credentials are actually being resolved.

At minimum, the implementation needs to distinguish:

- file-backed auth under the managed home
- keychain-backed or shared store modes
- unknown/unverified modes

Phase 1 does not need to solve every mode, but it must surface whether later one-click switching is trustworthy for a managed account.

This directly satisfies ACCT-06 and prevents false confidence later.

### 5. Reuse CodexBar patterns selectively

Strong candidates to port or mirror:

- `CodexManagedAccounts.swift`
- `ManagedCodexAccountStore`
- `CodexHomeScope`
- `ManagedCodexAccountService`
- visible-account reconciliation concepts

Do not port multi-provider settings infrastructure or OpenAI web/dashboard extras into Phase 1.

### 6. Keep Phase 1 strictly pre-switch

Do not let this phase mutate live `~/.codex` or attempt restart automation.

Phase 1 should only establish:

- trusted account inventory
- trusted identity view
- later switchability signals

That keeps the phase small, testable, and aligned with the roadmap.

## Required Behaviors Per Requirement

### ACCT-01

Need a scoped login flow that launches Codex with a managed home and persists the resulting account record only after identity is confirmed.

### ACCT-02

Need a UI-facing projection that lists account email, last auth time, active/live status, and trust/support metadata.

### ACCT-03

Need a persisted CodeRelay-active account selection that can be corrected by reconciliation if underlying account state drifts.

### ACCT-04

Need re-authentication to update an existing record instead of creating duplicates. Matching should prefer stable account ID when initiated from an existing row, then reconcile by normalized identity.

### ACCT-05

Need safe account removal with guarded deletion of managed-home directories only under the app-owned root.

### ACCT-06

Need a user-visible state model such as:

- `supported`
- `unsupported`
- `unverified`

with explanatory copy derived from credential-store detection.

## Suggested Code Boundaries For Planning

Phase 1 should likely create or prepare these files/modules:

- `Package.swift`
- `Sources/CodeRelayApp/`
- `Sources/CodeRelayCore/ManagedAccount.swift`
- `Sources/CodeRelayCore/ManagedAccountStore.swift`
- `Sources/CodeRelayCore/AccountSupportState.swift`
- `Sources/CodeRelayCodex/CodexHomeScope.swift`
- `Sources/CodeRelayCodex/CodexLoginRunner.swift`
- `Sources/CodeRelayCodex/CodexIdentityReader.swift`
- `Sources/CodeRelayCodex/CredentialStoreDetector.swift`
- `Sources/CodeRelayCore/AccountReconciler.swift`
- `Sources/CodeRelayApp/Accounts/…` for the narrow Phase 1 account-management surface
- `Tests/…` for store, reconciler, and detector coverage

Exact names can vary, but the planner should preserve the split between:

- app shell / views
- pure account domain
- Codex-specific integration

## Risks That Planning Must Respect

### Risk 1: hidden shared auth state

If the app assumes per-home isolation while Codex still resolves shared credentials elsewhere, later switching will be misleading.

Planner response:

- include a concrete credential-store detection task
- expose support state in the domain model

### Risk 2: duplicate or overwritten accounts during re-auth

If the app creates new rows on every re-auth, the account model becomes noisy and unsafe.

Planner response:

- include explicit deduplication and reconciliation logic
- persist auth refresh timestamps separately from account identity

### Risk 3: unsafe deletion

Removing an account must not delete arbitrary directories.

Planner response:

- require root-bounded deletion validation for managed homes

### Risk 4: Phase 1 drifting into switching

Phase 1 should not include live `~/.codex` mutation, process control, or session resume.

Planner response:

- keep switch-related outputs limited to support-state visibility only

## Recommended Plan Shape

Phase 1 should likely split into 2-3 plans:

1. Foundation/package/module scaffolding plus managed account models/store
2. Codex integration layer for scoped login, identity read, and credential-store detection
3. Thin Phase 1 UI/state layer for account listing, active selection, re-auth, removal, and support-state display

This allows parallelism while keeping strong boundaries.

## Validation Architecture

Phase 1 should establish fast automated feedback immediately.

Recommended validation direction:

- Framework: `swift test`
- Quick run command: `swift test --filter Phase1`
- Full suite command: `swift test`
- Estimated runtime target: under 30 seconds for quick validation

Tests to prioritize:

- managed account JSON store round-trip and version handling
- deduplication/re-auth reconciliation behavior
- root-bounded managed-home deletion safety
- credential-store detection classification
- active/live account projection rules

Manual verification should be limited to:

- basic Phase 1 account-management UI sanity

## Planning Guidance

The planner should optimize for:

- file-backed safety over clever abstractions
- explicit support-state visibility
- strict separation between managed account inventory and live/system observation
- small, testable vertical slices

The planner should avoid:

- multi-provider abstractions
- database-first design
- Phase 1 switch transactions
- Codex App automation

## Sources

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/research/SUMMARY.md`
- `.planning/research/STACK.md`
- `.planning/research/ARCHITECTURE.md`
- `.planning/research/PITFALLS.md`
- `CLAUDE.md`
- `AGENTS.md`
