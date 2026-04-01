# Feature Landscape

**Domain:** Codex-only macOS account continuity app
**Researched:** 2026-04-01

CodeRelay should optimize for one narrow job: keep a macOS developer coding when one Codex account is nearing exhaustion. The reference products are useful in two different ways: CodexBar shows the right ambient macOS UX and trustworthy Codex usage/account modeling, while cc-switch proves that live Codex account switching via `~/.codex/auth.json` and `config.toml` is viable. CodeRelay should combine those lessons without inheriting their multi-provider sprawl.

## Table Stakes

Features users will expect in v1. Missing these means CodeRelay does not solve the core workflow.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Managed Codex account roster | The product exists to manage multiple Codex accounts in one place. | Medium | Add, inspect, re-authenticate, remove, and choose the active account. Show account email, auth freshness, and whether the live system account already matches a stored account. |
| Trustworthy active-account usage card | Warnings and switch decisions are only credible if current usage is accurate. | High | Show 5-hour usage, weekly usage, reset timing, last refresh, and stale/error state for the active account. Prefer the most reliable local Codex source available, but surface when data is partial. |
| Candidate-account readiness view | A switch flow is incomplete if the user cannot tell which other account is actually usable. | Medium | For each managed account, show enough state to answer “can I switch now?” At minimum: reachable/authenticated, recent usage snapshot or unknown state, and whether it likely has remaining headroom. |
| Configurable low-usage warning | Warning-first behavior is a stated product requirement. | Medium | Let the user set a threshold for the active account and warn before the account becomes effectively unusable. Warnings should identify which limit is the problem: 5-hour window, weekly window, or both. |
| Confirmed one-click account switch | cc-switch already proves config-file switching solves the core pain. Users will expect CodeRelay to remove manual edits. | High | Switch by atomically replacing live Codex auth/config, preserving unrelated config content, and rolling back cleanly if any write fails. The action must be explicit and user-confirmed. |
| Client restart orchestration | Writing config files is not enough; the current pain is having to manually restart Codex tooling. | High | Tell the user what will be closed, which account will become active, then shut down and relaunch the current Codex client path: CLI or Codex App. Refresh usage after relaunch. |
| Best-effort conversation continuity | “Keep me coding” implies more than auth switching; it implies getting back to the interrupted task. | High | Capture current session context when possible, attempt resume after relaunch, and fall back to a copyable/manual resume path if the current conversation cannot be restored automatically. |
| Ambient macOS quick access | CodexBar sets the bar for low-friction access. Heavy users will expect warnings and switching to live near the workflow, not behind a heavy admin screen. | Medium | A menu bar presence or similarly lightweight always-available control surface should expose active account health, warning state, and a fast path into switching. Detailed settings can live in a fuller window. |

## Differentiators

Features worth planning after the core workflow is stable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Cross-account exhaustion planner | Turns CodeRelay from reactive switching into proactive workload planning. | High | Predict which account should be used next based on remaining window headroom and reset timing across all managed accounts. |
| Usage pace forecast | Raw percentages are blunt. A “runs out in…” forecast makes warnings earlier and more actionable. | Medium | Reuse the CodexBar-style pace idea to estimate time-to-depletion versus time-to-reset for the active account. |
| Project-aware restore | Restoring the right conversation in the wrong directory still breaks flow. | High | Reopen the correct project directory, then resume the matching Codex conversation or CLI session. This is stronger than a generic resume-command fallback. |
| Config drift self-healing | Reduces failure cases when live `~/.codex` state diverges from what CodeRelay thinks is active. | Medium | Detect auth/config mismatches, unreadable stores, or a live account that already matches a stored account, then offer a guided fix instead of a silent failure. |
| Multi-account overview timeline | Gives power users a control tower for the day’s rotation strategy. | Medium | Side-by-side view of all accounts, latest usage snapshots, reset times, and recent switch history. Useful once core switching is reliable. |

## Anti-Features

Features to explicitly keep out of v1.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Multi-provider or multi-CLI switching | Reintroduces the abstraction and UI surface area that CodeRelay is deliberately avoiding. | Stay Codex-only in the domain model, copy, settings, and switch engine. |
| Proxy/router/failover/vendor marketplace features | cc-switch covers this category already. It is a different problem with different safety and support burdens. | Limit v1 to official-style Codex account switching through local live config replacement. |
| Unified MCP, prompts, skills, or config management | This would turn CodeRelay into a full workspace manager and bury the main job to be done. | Preserve existing Codex config during switching, but do not become the editor or owner of those broader settings. |
| Full session manager and transcript browser | cc-switch’s session manager is powerful, but browsing/searching/deleting history is not required to validate CodeRelay’s core value. | Only capture enough session context to resume the interrupted Codex workflow after a switch. |
| Silent automatic account switching | It conflicts with the explicit warning-first requirement and can unexpectedly interrupt live work. | Warn automatically, recommend candidates, require a deliberate confirmation to switch. |
| Cross-device sync and team features | The v1 problem is single-machine continuity for one developer, not fleet or team coordination. | Keep state local on macOS and optimize for fast, reliable local recovery. |

## Feature Dependencies

```text
Managed account roster + live/stored account reconciliation
  -> Active account selection
  -> Candidate-account readiness view

Active-account usage snapshot + freshness/error handling
  -> Low-usage warning
  -> Candidate ranking/recommendation

Managed account config snapshot + safe write/rollback
  -> Confirmed one-click account switch
  -> Client restart orchestration

Current client/session/project detection
  -> Best-effort conversation continuity
  -> Project-aware restore

Ambient quick-access UI
  -> Depends on warnings + switch flow being reliable enough to expose as a fast action
```

## UX Caveats

- Warnings should say why the account is at risk. “Low usage” is too vague; users need to know whether the 5-hour window, weekly window, or stale data is driving the warning.
- Switching should preview side effects before confirmation: target account email, whether Codex CLI or Codex App will be restarted, and whether automatic resume is available or only best-effort.
- Resume must be presented as opportunistic, not guaranteed. If CodeRelay cannot recover a session ID or working directory, it should say so before the user switches.
- Candidate accounts with stale or unknown usage should never be labeled “safe.” Unknown should stay unknown.
- Re-auth and remove actions should respect the distinction between a stored managed account and the currently live system account, mirroring CodexBar’s visible-account reconciliation model.

## MVP Recommendation

Prioritize:
1. Managed Codex accounts with active/live reconciliation
2. Active-account usage visibility plus configurable warning thresholds
3. Safe confirmed switch with restart orchestration and best-effort resume

Defer: cross-account exhaustion planning. It is valuable, but it depends on reliable background refresh and prediction quality across all accounts, which is not required to prove the core continuity workflow.

## Sources

- `CodeRelay/.planning/PROJECT.md`
- `CodexBar/README.md`
- `CodexBar/docs/codex.md`
- `CodexBar/Sources/CodexBar/PreferencesCodexAccountsSection.swift`
- `CodexBar/Sources/CodexBar/CodexAccountReconciliation.swift`
- `cc-switch/README_ZH.md`
- `cc-switch/src-tauri/src/codex_config.rs`
- `cc-switch/src-tauri/src/services/config.rs`
- `cc-switch/session-manager.md`
