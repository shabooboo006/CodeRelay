# CodeRelay

## What This Is

CodeRelay is a macOS desktop app for heavy Codex users who need to keep working after a single Plus account approaches its sliding-window or weekly usage limits. It manages multiple Codex accounts, monitors account usage in near real time, warns before depletion, and gives the user a one-click path to switch into another managed account without manually rebuilding their workflow.

The product is intentionally narrower than generic provider switchers: it starts from lessons in CodexBar and cc-switch, but the shipped app only focuses on Codex account management, usage awareness, account switching, and workflow continuity across Codex CLI and Codex App restarts.

## Core Value

Keep a macOS developer continuously productive in Codex by making account exhaustion visible early and account switching fast, explicit, and low-friction.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can add, inspect, and manage multiple Codex accounts inside one macOS app.
- [ ] User can see current Codex 5-hour sliding-window usage, weekly usage, and reset timing for the active account.
- [ ] User can define a low-usage warning threshold and receive a warning before an account is effectively exhausted.
- [ ] User can confirm a one-click switch into another managed Codex account with enough remaining usage.
- [ ] User can switch accounts with automatic shutdown and relaunch of the active Codex client, then resume the prior conversation when possible.

### Out of Scope

- Multi-provider support beyond Codex — this project is deliberately narrower than CodexBar and cc-switch to reduce surface area and ship the core workflow faster.
- Non-macOS desktop targets in v1 — the product need is driven by a macOS workflow with native app control, window lifecycle handling, and local CLI/App relaunch.
- Generic provider marketplace, proxy routing, or API relay management — those are separate product categories already covered by tools like cc-switch.

## Context

The workspace is a multi-repo reference environment:

- `CodeRelay/` is the real implementation repository and is currently empty.
- `CodexBar/` is a reference macOS app with strong menu bar UX and existing Codex usage-monitoring logic.
- `cc-switch/` is a reference desktop app whose Codex configuration-file switching flow has already been verified by the user with three Codex accounts.

Problem background:

- A single Codex Plus account can run out of the 5-hour sliding-window budget quickly during sustained coding sessions.
- The user already has working proof that switching Codex configuration files can switch accounts, but restarting Codex CLI/App still requires manual steps.
- The desired product behavior is warning-first, not forced auto-switching. When usage reaches the configured threshold, the app should warn the user. After the warning, the user can choose a managed account and perform a confirmed one-click switch.

Product expectations gathered so far:

- The UI and implementation quality should take inspiration from CodexBar.
- The provider abstraction should be collapsed to Codex only.
- The switching engine should reuse or mirror the proven config-handling approach from cc-switch where appropriate.
- When switching, the app should tell the user it will close the current Codex CLI or Codex App, relaunch the matching client for the target account, and then refresh usage state.
- If the user was in an active Codex conversation before restart, the system should attempt to reopen that conversation via Codex resume support.

## Constraints

- **Platform**: macOS desktop app first — the required client shutdown, relaunch, and user workflow restoration are platform-specific.
- **Scope**: Codex-only provider model — v1 must remove unrelated provider-management complexity from the foundation.
- **Dependencies**: No new dependencies without explicit request — implementation should prefer existing patterns from the chosen foundation and native platform capabilities.
- **Reference Strategy**: Build from CodexBar concepts and UX, but selectively port only the Codex-relevant pieces — direct wholesale adoption would preserve too much irrelevant provider complexity.
- **Switch Safety**: Account changes must remain explicit and user-confirmed — the product should warn automatically but not silently force account switches.
- **Continuity**: Conversation continuity matters — restart flow must preserve or restore the prior Codex session where possible.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Treat `CodeRelay/` as the only implementation repo | The outer workspace is only a reference container; planning and delivery should stay attached to the real ship target | — Pending |
| Use CodexBar as the primary product and UX reference | It already demonstrates a macOS-native app, polished interaction design, and Codex usage monitoring | — Pending |
| Reuse cc-switch's Codex config-switching approach as an implementation reference, not as the app foundation | The user has already validated that config-file switching works for multiple Codex accounts | — Pending |
| Ship warning-first account switching instead of silent auto-switching | The user wants control over when to leave the current account after being warned | — Pending |
| Collapse the provider model to Codex-only for v1 | Narrow scope improves clarity, reduces technical drag, and aligns with the actual job to be done | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check -> still the right priority?
3. Audit Out of Scope -> reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-01 after initialization*
