# Architecture Patterns

**Domain:** Codex-only macOS account relay
**Researched:** 2026-04-01
**Overall confidence:** MEDIUM-HIGH

## Recommended Architecture

CodeRelay should be a narrow, Codex-specific macOS app with a strict split between:

1. `CodeRelayCore`
   - Codex account storage
   - account-scoped usage probing
   - account reconciliation
   - session discovery
   - CLI lifecycle control
   - switch orchestration
   - durable journals/caches
2. `CodeRelayApp`
   - SwiftUI/AppKit shell
   - menu bar + settings UI
   - notifications
   - view models and command routing

For v1, the runtime model should be **CLI-first and managed-home-first**:

- Each managed account owns its own Codex home under app-controlled storage.
- Monitoring probes each account by setting `CODEX_HOME` to that managed home, following the same scoped-environment pattern used by CodexBar.
- Switching does **not** rewrite ambient `~/.codex` in v1.
- Restart/resume works by relaunching Codex CLI with `CODEX_HOME=<targetManagedHome>`.
- Ambient `~/.codex` is still observed so the app can show the currently live system account, but it is not the v1 switch target.

This is the cleanest build order after the scope update: it preserves CodexBar’s safe account isolation, uses the cc-switch lesson that switching must be orchestrated as an explicit transaction, and avoids forcing Codex App automation requirements into the first implementation.

```text
CodeRelayApp
  -> AppStateStore / ViewModels
  -> BackgroundCoordinator
      -> AccountMonitor
          -> CodexProbeRunner
              -> ManagedCodexHomeStore
              -> AmbientCodexObserver
      -> SessionCatalog
          -> SessionScanner
      -> WarningEngine
  -> SwitchCommand
      -> SwitchOrchestrator
          -> SwitchJournalStore
          -> CLILifecycleController
          -> ResumePlanner
          -> PostSwitchVerifier

Deferred seam:
  FutureCodexAppAdapter
    -> optional LiveHomeProjector / app automation
```

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `ManagedAccountService` | Create, re-authenticate, and remove managed accounts; own managed Codex home directories | `ManagedAccountStore`, `CodexLoginRunner`, `CodexProbeRunner` |
| `ManagedAccountStore` | Durable catalog of managed accounts (`id`, `email`, `managedHomePath`, timestamps) | `ManagedAccountService`, `AccountReconciler`, `SwitchOrchestrator` |
| `AmbientAccountObserver` | Read the currently live system Codex account from the ambient environment without mutating it | `AccountReconciler`, `AccountMonitor` |
| `AccountReconciler` | Merge managed accounts plus the ambient live account into one user-visible projection; resolve active source drift | `ManagedAccountStore`, `AmbientAccountObserver`, `AppStateStore` |
| `CodexProbeRunner` | Run usage/account probes against a specific Codex home by scoping `CODEX_HOME` | `AccountMonitor`, `ManagedAccountService`, `PostSwitchVerifier` |
| `AccountMonitor` | Background refresh scheduler for usage, reset windows, and account identity snapshots | `CodexProbeRunner`, `WarningEngine`, `AppStateStore` |
| `WarningEngine` | Apply low-usage thresholds, cooldowns, and target-account ranking for switch suggestions | `AccountMonitor`, `NotificationService`, `AppStateStore` |
| `SessionCatalog` | Discover resumable Codex sessions from session logs and cache recent session metadata | `ResumePlanner`, `SwitchOrchestrator`, `AppStateStore` |
| `ResumePlanner` | Decide whether a resume attempt is possible, and build the CLI command/cwd for it | `SessionCatalog`, `SwitchOrchestrator`, `CLILifecycleController` |
| `CLILifecycleController` | Track CodeRelay-launched Codex CLI processes, terminate them safely, and relaunch in the chosen terminal | `SwitchOrchestrator`, `ProcessRegistry` |
| `ProcessRegistry` | Store the PID, terminal target, launch cwd, and managed-home context for CodeRelay-launched CLI sessions | `CLILifecycleController`, `ResumePlanner` |
| `SwitchOrchestrator` | Single transaction owner for switch preflight, journal, stop/start, verify, and rollback | `ManagedAccountStore`, `AccountReconciler`, `ResumePlanner`, `CLILifecycleController`, `SwitchJournalStore` |
| `SwitchJournalStore` | Durable record of in-flight and last-completed switch transactions for crash recovery | `SwitchOrchestrator`, `AppStateStore` |
| `NotificationService` | User-facing warnings and switch outcome notifications | `WarningEngine`, `SwitchOrchestrator` |
| `FutureCodexAppAdapter` | Deferred Codex App restart/resume capability; validates whether app automation or live-home projection is required | Future phase only |

## Persistence Design And State Ownership

CodeRelay should keep authoritative state in app-controlled files under Application Support, and keep UI-only preferences in `UserDefaults`.

| State | Owner | Storage | Notes |
|------|-------|---------|------|
| Managed account catalog | `ManagedAccountStore` | `Application Support/CodeRelay/managed-codex-accounts.json` | Versioned JSON, `0600` permissions, authoritative app-owned record |
| Managed account homes | `ManagedAccountService` | `Application Support/CodeRelay/managed-codex-homes/<account-id>/` | Each home contains Codex auth/config/session data for that account |
| Active source + selected account | `AppStateStore` | `UserDefaults` or small `state.json` | Durable UI/domain preference, but always corrected by reconciliation on launch |
| Warning threshold, cooldown, preferred terminal | `PreferencesStore` | `UserDefaults` | Small user preferences, not part of switch transaction |
| Usage snapshot cache | `AccountMonitor` | `Application Support/CodeRelay/usage-cache.json` | Derived cache only; safe to rebuild |
| Session metadata cache | `SessionCatalog` | `Application Support/CodeRelay/session-cache.json` | Cache of `sessionId`, `cwd`, `summary`, `lastActiveAt`, `homePath` |
| Switch journal | `SwitchJournalStore` | `Application Support/CodeRelay/switch-journal.json` | Must persist `prepared`, `launching`, `verified`, `failed`, `rolledBack` states |
| Process registry | `ProcessRegistry` | `Application Support/CodeRelay/process-registry.json` | Tracks only CodeRelay-launched CLI sessions |
| Ambient `~/.codex` | External system state | Not owned by CodeRelay in v1 | Observed only; do not mutate during v1 CLI-first flow |

### State ownership rules

- `ManagedAccountStore` is the source of truth for which managed accounts exist.
- `AccountReconciler` owns the user-visible merged view of ambient + managed accounts.
- `AccountMonitor` owns live usage state, but that state is always derived from probes and is never authoritative.
- `SwitchOrchestrator` is the only component allowed to change active-account runtime state.
- `ResumePlanner` may suggest a resume command, but it does not own switch success. Resume is best-effort.

## Data Flow

### Monitoring

1. `BackgroundCoordinator` starts a refresh tick.
2. `AccountReconciler` loads the managed account catalog and the ambient live account.
3. `AccountMonitor` builds a probe list:
   - active source first
   - likely switch candidates next
   - remaining accounts at lower cadence
4. For each managed account, `CodexProbeRunner` probes with `CODEX_HOME=<managedHome>`.
5. For the ambient live account, `CodexProbeRunner` probes without changing environment.
6. Probe results are keyed by normalized email plus source, like CodexBar’s account-scoped refresh guard pattern.
7. `AppStateStore` publishes the latest usage/reset state to the UI.

### Warning

1. `WarningEngine` receives refreshed usage snapshots.
2. It compares the active account against the configured low-usage threshold and notification cooldown.
3. If the active account is near exhaustion, it ranks alternate managed accounts by:
   - above-threshold availability
   - latest successful probe
   - recency of authentication
4. `NotificationService` emits a warning with a switch action.
5. The warning state is persisted so the app does not spam duplicate alerts for the same depletion window.

### Session Discovery

1. `SessionCatalog` scans session logs for the active CLI home.
2. For v1, the primary source is the active managed home for CodeRelay-launched CLI sessions.
3. Ambient `~/.codex/sessions` can still be scanned for observational UI, but those sessions are not guaranteed to be auto-restartable.
4. Session metadata includes:
   - `sessionId`
   - `cwd`
   - `sourcePath`
   - `summary`
   - `lastActiveAt`
   - derived `resumeCommand` template such as `codex resume <sessionId>`

This follows cc-switch’s proven pattern: session restore should come from lightweight session metadata discovery, not from coupling resume logic to config writing.

## Control Flow

### Switching

1. User confirms a switch to a target managed account.
2. `SwitchOrchestrator` acquires the global switch lock. No other destructive action can run concurrently.
3. It loads:
   - current reconciled source
   - target account record
   - latest usage snapshot
   - tracked CLI process info
   - best available resume candidate
4. Preflight checks run:
   - target managed home exists
   - target account identity is readable
   - target account is not already active
   - target account has a recent successful usage probe or can be probed now
   - Codex CLI binary is available
5. `SwitchJournalStore` persists a `prepared` transaction with `from`, `to`, `resumeCandidate`, `cwd`, and rollback metadata.
6. `CLILifecycleController` stops the tracked CodeRelay-launched CLI process if one exists.
7. `AppStateStore` flips active source to the target managed account.
8. `ResumePlanner` chooses launch mode:
   - `codex resume <sessionId>` in the prior cwd when a valid candidate exists
   - plain `codex` otherwise
9. `CLILifecycleController` relaunches Codex CLI in the preferred terminal with `CODEX_HOME=<targetManagedHome>`.
10. `PostSwitchVerifier` re-probes the target managed home and confirms that the observed account matches the target email.
11. If verification succeeds, the journal is marked `verified`, warnings are cleared, and the UI refreshes.
12. If launch or verification fails, the journal is marked `failed` and rollback is offered.

### Restart

For v1, automatic restart should be **guaranteed only for CodeRelay-launched Codex CLI sessions**. That keeps the app from killing arbitrary terminal processes.

Behavior:

- If CodeRelay owns the current CLI PID, it can terminate and relaunch automatically.
- If the active Codex CLI session was launched outside CodeRelay, the switch flow should downgrade cleanly:
  - warn the user that the existing terminal session is unmanaged
  - still allow launching a new CLI session under the target account
  - do not promise automatic shutdown of the external session

### Resume

Resume is best-effort, not part of the success definition for the switch itself.

1. `SessionCatalog` identifies the most recent resumable session for the current CLI home.
2. `ResumePlanner` captures `sessionId`, `cwd`, and the command template before shutdown.
3. After the new CLI session launches under the target managed home, CodeRelay tries the resume command.
4. If `codex resume` fails, the app reports:
   - switch succeeded
   - resume failed
   - fallback is a fresh `codex` session plus access to the copied resume command

This separation is important because cross-home or cross-account resume behavior is not the right architectural dependency for v1 switching.

## Patterns To Follow

### Pattern 1: Scoped Codex Home Probing

**What:** Probe usage and account identity by injecting `CODEX_HOME` for managed accounts instead of mutating the live system home.

**When:** Every background refresh, preflight check, and post-switch verification.

**Why:** This is the cleanest reusable lesson from CodexBar. Monitoring remains isolated from switching.

### Pattern 2: Single-Writer Switch Actor

**What:** All switch operations run through one serialized orchestrator.

**When:** Any action that changes active account runtime state or restarts CLI.

**Why:** Prevents double-switch races, overlapping CLI relaunches, and broken rollback state.

### Pattern 3: Journal Before Side Effects

**What:** Persist the intended switch transaction before stopping the current CLI session.

**When:** Immediately after preflight succeeds.

**Why:** A crash during restart must leave recoverable state, not ambiguity.

### Pattern 4: Reconciled Visible State

**What:** Keep ambient account detection and managed-account storage separate, then merge them into a derived projection.

**When:** App launch, refresh, account add/remove, and switch completion.

**Why:** This is directly borrowed from CodexBar and avoids fragile “one store means one truth” assumptions.

## Anti-Patterns To Avoid

### Anti-Pattern 1: Generic Provider Abstraction

**What:** Rebuilding CodexBar/cc-switch as a multi-provider framework inside CodeRelay.

**Why bad:** It reintroduces complexity the project explicitly removed.

**Instead:** Keep Codex-only services with seams only where v2 capabilities obviously need them.

### Anti-Pattern 2: Ambient Home Mutation In v1

**What:** Writing target account credentials into `~/.codex` as the core v1 switch path.

**Why bad:** It increases rollback surface area, makes CLI monitoring less isolated, and adds confusion before Codex App support is even validated.

**Instead:** Use managed homes plus `CODEX_HOME` for CLI-first switching. Add a separate live-home projection layer later only if Codex App support demands it.

### Anti-Pattern 3: Making Resume Part Of Switch Correctness

**What:** Declaring the entire switch failed if `codex resume` fails.

**Why bad:** Resume capability is a helpful restoration layer, not the account-switch primitive.

**Instead:** Treat switch success and resume success as separate outcomes.

### Anti-Pattern 4: Killing Unmanaged Terminal Sessions

**What:** Trying to terminate any process that looks like Codex CLI.

**Why bad:** Unsafe on a developer workstation and difficult to reason about.

**Instead:** Track and control only CodeRelay-launched CLI processes in v1.

## Suggested Build Order

### Phase 1: Core Account Foundation

Build:

- `ManagedAccountService`
- `ManagedAccountStore`
- managed home creation/login/reauth
- `AmbientAccountObserver`
- `AccountReconciler`
- `AppStateStore`

Why first:

- Everything else depends on account identity, managed-home isolation, and a reliable active-source model.
- This is the lowest-risk port from CodexBar.

### Phase 2: Monitoring And Warning

Build:

- `CodexProbeRunner`
- `AccountMonitor`
- `WarningEngine`
- notifications + menu bar/status UI

Why second:

- It delivers user value early without changing external client state.
- It validates whether scoped probing works across multiple managed accounts before any restart logic exists.

### Phase 3: CLI Session Catalog

Build:

- `SessionCatalog`
- session cache
- resume command generation
- process registry for CodeRelay-launched CLI sessions

Why third:

- Restart/resume needs concrete session metadata first.
- cc-switch’s session model is useful, but it should remain observational until switching is stable.

### Phase 4: CLI Switch Transaction

Build:

- `SwitchOrchestrator`
- `SwitchJournalStore`
- `CLILifecycleController`
- preflight + rollback
- launch fresh `codex` under `CODEX_HOME=<targetManagedHome>`

Why fourth:

- By now the app already knows accounts, usage, and sessions.
- The first successful switch should not depend on resume yet.

### Phase 5: Best-Effort CLI Resume

Build:

- `ResumePlanner`
- post-launch resume attempt
- copied-command/manual fallback UX
- verification/reporting split between switch success and resume success

Why fifth:

- Resume has more uncertainty than account switching.
- Keeping it after the switch transaction prevents false coupling and rework.

### Phase 6: Codex App Technical Validation

Build:

- validate whether Codex App can be launched with isolated home semantics
- if not, design `FutureCodexAppAdapter` plus optional `LiveHomeProjector`
- only then decide whether ambient `~/.codex` mutation is necessary

Why last:

- The user explicitly moved this out of v1.
- It should be a dedicated technical validation phase, not an assumption hidden inside the v1 core.

## Phase Implications

| Phase Topic | Architectural implication | Reason |
|-------------|---------------------------|--------|
| Managed accounts | Must exist before monitoring | Probing depends on account-scoped homes |
| Monitoring | Should ship before switching | Validates low-risk value and probe correctness |
| Session scanning | Should precede resume automation | Resume needs discovered metadata, not guesses |
| CLI switching | Should precede CLI resume | Restart path must stand alone before restoration is layered on |
| Codex App support | Separate validation phase | Prevents GUI automation requirements from forcing v1 design |

## Confidence And Open Questions

### High confidence

- Managed account isolation through app-owned Codex homes.
- Scoped probing with `CODEX_HOME`.
- Account reconciliation as a derived projection.
- CLI session metadata scanning and resume-command generation patterns.

### Medium confidence

- How reliably `codex resume <sessionId>` works when the resumed session originated from a different home/account context.
- Whether unmanaged ambient CLI sessions can be upgraded to a safe auto-restart path without intrusive terminal control.

### Questions to validate later

- Should CodeRelay eventually support a “project current ambient account into managed storage” import flow?
- Does Codex App require direct automation, live-home projection, or both?
- Is there a clean way to detect when a CodeRelay-launched CLI session has handed off to a child process tree that also needs tracking?

## Sources

- `CodeRelay/.planning/PROJECT.md` - product scope and v1 constraints
- `CodexBar/docs/architecture.md` - module split and refresh-loop shape
- `CodexBar/docs/codex.md` - Codex data sources and `CODEX_HOME`-scoped session paths
- `CodexBar/Sources/CodexBar/ManagedCodexAccountService.swift` - managed home/account creation pattern
- `CodexBar/Sources/CodexBar/CodexAccountReconciliation.swift` - visible account projection and active-source correction
- `CodexBar/Sources/CodexBar/Providers/Codex/CodexSettingsStore.swift` - fail-closed managed-account selection behavior
- `CodexBar/Sources/CodexBarCore/CodexHomeScope.swift` - scoped environment model
- `CodexBar/Sources/CodexBarCore/ManagedCodexAccountStore.swift` - durable account catalog pattern
- `CodexBar/Sources/CodexBarCore/CodexManagedAccounts.swift` - account schema and normalization
- `CodexBar/Sources/CodexBar/CodexSystemAccountObserver.swift` - ambient account observation
- `CodexBar/Sources/CodexBar/Providers/Codex/UsageStore+CodexAccountState.swift` - account-scoped invalidation/refresh pattern
- `cc-switch/src-tauri/src/codex_config.rs` - atomic config write/rollback lesson
- `cc-switch/src-tauri/src/services/config.rs` - explicit live sync service boundary
- `cc-switch/src-tauri/src/services/provider/live.rs` - live-config mutations belong in a dedicated service
- `cc-switch/src-tauri/src/session_manager/providers/codex.rs` - Codex session scanning and `codex resume <sessionId>` derivation
- `cc-switch/src-tauri/src/commands/session_manager.rs` - terminal-launch command boundary
- `cc-switch/session-manager.md` - restore flow, terminal fallback, and resume-command separation
