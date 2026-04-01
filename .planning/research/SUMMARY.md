# Project Research Summary

**Project:** CodeRelay
**Domain:** Codex-only macOS account continuity app
**Researched:** 2026-04-01
**Confidence:** MEDIUM-HIGH

## Executive Summary

CodeRelay is a narrow macOS utility for developers who rotate between multiple Codex accounts to avoid interruption when one account nears its usage limits. The research converges on a native Swift implementation, not Tauri: SwiftUI for settings and detail views, AppKit for the menu bar and lifecycle control, app-owned managed Codex homes for account isolation, and Codex CLI probes for trustworthy identity and rate-limit data. The product should stay Codex-only, local-first, warning-first, and explicit about what is authoritative versus what is stale or estimated.

For roadmap purposes, v1 should be CLI-first and managed-home-first. The app should create isolated Codex homes per account, monitor them via `CODEX_HOME`-scoped probes, and switch by relaunching CodeRelay-managed Codex CLI sessions under the target home. That gives a reliable continuity loop without making ambient `~/.codex` mutation or Codex App automation part of the critical path. Atomic live-home projection remains a useful later seam if Codex App support or unmanaged CLI interoperability requires it, but it should be validated separately rather than shaping v1 now.

The main risks are identity mistakes and over-promised continuity. Credential-store mode can make accounts look isolated when they are not; async refresh can show the wrong usage after a switch; process targeting can kill the wrong CLI session; and `codex resume` is best-effort, not perfect replay. The mitigation pattern is consistent across the research: richer per-account identity metadata, account-scoped refresh guards, a single journaled switch orchestrator, explicit session-ID capture, post-switch identity verification, and UX that distinguishes "switch succeeded" from "resume succeeded."

## Key Findings

### Recommended Stack

CodeRelay should be a native macOS 15+ app on Xcode 26.3+ and Swift 6.3 with strict concurrency. Reuse CodexBar's Codex-specific Swift patterns, but port them into CodeRelay-owned modules instead of depending on the whole CodexBar app. Use Developer ID direct distribution, local SwiftPM modules, JSON/JSONL plus Application Support directories for state, and no database, WebKit dashboard stack, or cross-platform abstraction in v1.

The main research conflict on switch mechanics should be resolved in favor of the architecture doc's safer runtime model for v1: managed-account homes plus `CODEX_HOME`-scoped CLI relaunch. Keep cc-switch's transaction and rollback discipline as a design influence, but defer live `~/.codex` projection until a later technical validation phase.

**Core technologies:**
- `Swift 6.3` with strict concurrency: app logic and background coordination, aligned with CodexBar's proven direction.
- `SwiftUI` plus `AppKit`: settings UI plus menu bar, notifications, lifecycle, and process control.
- Local SwiftPM modules: `CodeRelayApp`, `CodeRelayCore`, `CodeRelayCodex`, `CodeRelaySwitching`, `CodeRelayLauncher` for a clean ownership split.
- Versioned JSON and JSONL in `Application Support`: account catalog, usage cache, session cache, and switch journal without database overhead.
- Native macOS APIs: `Foundation.Process`, `NSWorkspace`, `UNUserNotificationCenter`, `SMAppService`, and `OSLog` for process management, quick access, login items, and diagnostics.
- Developer ID signed, notarized direct distribution: avoids App Store sandbox friction around `~/.codex`, process launching, and managed account homes.

### Expected Features

V1 must solve continuity, not become a general Codex workspace manager. The table-stakes set is: managed account roster, trustworthy active-account usage, candidate readiness, configurable low-usage warnings, explicit confirmed CLI handoff, lightweight quick-access UI, and best-effort CLI continuity using captured session metadata. This synthesis narrows the feature docs slightly: for v1, restart and resume should be guaranteed only for CodeRelay-launched Codex CLI sessions, with guided fallback for unmanaged terminals.

**Must have (table stakes):**
- Managed Codex account roster with live and managed reconciliation.
- Trustworthy active-account usage card with rate-limit windows, freshness, and stale or error state.
- Candidate-account readiness view for "which account is usable now?"
- Configurable low-usage warnings with cooldowns and reason labeling.
- Confirmed one-click CLI account handoff for CodeRelay-managed sessions.
- Best-effort CLI continuity using captured `sessionId` and `cwd`.
- Ambient menu bar access for warning state and fast switching.

**Should have (competitive):**
- Usage pace forecast instead of only raw percentages.
- Cross-account exhaustion planner for proactive routing.
- Project-aware restore that reopens the right repo before resuming.
- Config drift self-healing for managed versus observed state mismatches.

**Defer (v2+ / later validation):**
- Codex App close, relaunch, and resume automation.
- Ambient `~/.codex` projection as the primary switch path.
- Multi-provider switching, proxies, MCP or prompt management, transcript browsing, silent auto-switching, and sync or team features.

### Architecture Approach

The architecture should split into a narrow domain/runtime layer and a thin app shell. `CodeRelayCore` owns managed accounts, account reconciliation, usage probing, session discovery, warning policy, switch transactions, journals, and caches. `CodeRelayApp` owns SwiftUI and AppKit presentation, notifications, menu bar control, and command routing. The crucial v1 decision is that managed homes are authoritative and ambient `~/.codex` is observed, not mutated; switching means relaunching CLI with `CODEX_HOME=<targetManagedHome>`, then verifying identity and optionally attempting resume.

**Major components:**
1. `ManagedAccountService`, `ManagedAccountStore`, and `AccountReconciler` — create accounts, persist them, and merge managed plus ambient state into a safe user-visible model.
2. `CodexProbeRunner`, `AccountMonitor`, and `WarningEngine` — poll identity and usage per account, rank candidates, and trigger warnings without stale-result races.
3. `SessionCatalog`, `ProcessRegistry`, and `ResumePlanner` — discover resumable CLI sessions and build deterministic handoff commands.
4. `SwitchOrchestrator`, `SwitchJournalStore`, and `CLILifecycleController` — serialize switch transactions, stop and relaunch tracked CLI sessions, verify the target account, and offer rollback.
5. `FutureCodexAppAdapter` — a deferred seam for later Codex App validation, not v1 scope.

### Critical Pitfalls

1. **Credential-store mode breaks isolation assumptions** — detect `cli_auth_credentials_store`, store auth mode in the identity envelope, and block or downgrade one-click switching when the account is not file-isolated.
2. **Email-only identity merges the wrong account** — match on a richer identity envelope: email, auth mode, credential store, workspace identifier when available, managed home, and last validated source.
3. **Async monitoring can overwrite the newly active account** — bind every refresh to an account key plus switch token and drop late results after a handoff.
4. **Process targeting can kill the wrong CLI session** — only auto-restart CodeRelay-launched CLI processes with captured PID, repo path, cwd, and session ID; otherwise use a guided handoff.
5. **Resume is not perfect replay** — capture explicit `sessionId`, do not rely on `codex resume --last` when an ID is available, and message continuity as best-effort even when switch succeeds.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Account Foundation And Secure Storage
**Rationale:** Everything depends on trustworthy account identity and real managed-home isolation.
**Delivers:** `ManagedAccountService`, `ManagedAccountStore`, managed-home creation, reauth flow, ambient account observation, reconciliation, richer identity envelope, and storage-mode detection.
**Addresses:** Managed account roster and live versus managed account reconciliation.
**Avoids:** Credential-store mode failures, email-only identity mistakes, auth leakage, and destructive reauth cleanup.

### Phase 2: Monitoring, Usage Confidence, And Warning UX
**Rationale:** It delivers user value without changing external client state and validates the probing model before any restart logic exists.
**Delivers:** `CodexProbeRunner`, `AccountMonitor`, usage cache, freshness and source labeling, candidate readiness, threshold warnings, cooldowns, and menu bar or status UI.
**Addresses:** Trustworthy active-account usage, candidate readiness, configurable warnings, and ambient quick access.
**Avoids:** Fixed-message-count UX, stale refresh overwrite, warning flapping, and over-trusting browser or dashboard data.

### Phase 3: CLI Session Catalog And Process Targeting
**Rationale:** Switching and continuity need concrete session and process data before any restart automation is safe.
**Delivers:** `SessionCatalog`, session cache, explicit `sessionId` capture, process registry, repo and `cwd` tracking, and unmanaged-session downgrade UX.
**Addresses:** Best-effort continuity foundation and clearer switch previews.
**Avoids:** Killing the wrong CLI session, relying on `resume --last`, and ambiguous restart targeting.

### Phase 4: Journaled CLI Switch Transaction
**Rationale:** This is the first destructive phase, so it should land only after identity, monitoring, and process targeting are proven.
**Delivers:** `SwitchOrchestrator`, switch journal, preflight checks, tracked CLI shutdown, relaunch under `CODEX_HOME=<targetManagedHome>`, target identity verification, rollback, and post-switch refresh.
**Addresses:** Confirmed one-click CLI account handoff.
**Avoids:** Non-transactional switches, partial state, wrong-account relaunches, and unmanaged-process termination.

### Phase 5: Best-Effort CLI Continuity And Trust UX
**Rationale:** Resume is valuable, but it should be layered after switching works on its own.
**Delivers:** `ResumePlanner`, resume-by-session-ID attempt, copied-command or manual fallback, handoff record, and UI that separates switch success from resume success.
**Addresses:** Best-effort conversation continuity and project-aware restore groundwork.
**Avoids:** Over-promising perfect continuity, wrong-session restore, and loss of auditability after resume regressions.

### Phase 6: Codex App Technical Validation
**Rationale:** The latest scope decision explicitly moves Codex App restart and resume out of v1. It should be treated as a technical spike, not hidden scope.
**Delivers:** Validation of Codex App launch and relaunch constraints, whether live `~/.codex` projection is required, whether automation or accessibility control is viable, and a go or no-go architecture decision for post-v1 work.
**Addresses:** Deferred Codex App restart and resume only.
**Avoids:** Blocking v1 on opaque GUI automation or forcing ambient-home mutation too early.

### Phase Ordering Rationale

- Managed account identity and secure storage must come before any monitoring or switching because every later decision depends on knowing which account is actually active.
- Monitoring should ship before switching because it validates account-scoped probing, warning credibility, and candidate ranking without destructive side effects.
- Session and process capture must precede restart and resume so the app can target a specific CLI session instead of guessing.
- Switching must stand alone before resume layering; switch success and resume success are separate outcomes.
- Codex App support should be a dedicated later phase because it is a different risk class from CLI continuity and should not shape the v1 architecture.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4:** Validate one-click switching behavior across credential-store modes and confirm the exact boundary between managed-home relaunch and any unavoidable live-home projection.
- **Phase 5:** Re-check current `codex resume <sessionId>` behavior and transcript fidelity against the current Codex CLI release during planning and before ship.
- **Phase 6:** Full `/gsd:research-phase` recommended; Codex App lifecycle control is explicitly unvalidated and may require a different technical approach.

Phases with standard patterns (skip research-phase):
- **Phase 1:** CodexBar already provides a strong managed-home, account-store, and reconciliation reference.
- **Phase 2:** Native macOS polling, menu bar UI, notifications, and threshold or cooldown logic are established patterns.
- **Phase 3:** Session scanning, caching, and tracked-process registries are straightforward local-system patterns once scope is limited to CodeRelay-launched CLI sessions.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Strong convergence on native Swift, local module split, managed-home storage, and no DB, WebKit, or Tauri foundation for v1. |
| Features | HIGH | Core workflow is clear and narrow; the main ambiguity is how much v1 should promise for restart and resume, resolved here in favor of CodeRelay-launched CLI sessions only. |
| Architecture | MEDIUM | The research agrees on most components but conflicts on whether v1 should mutate ambient `~/.codex`; this synthesis resolves that in favor of managed-home CLI switching. |
| Pitfalls | HIGH | Risks are concrete, repeated across sources, and tied to specific prevention strategies. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Credential-store compatibility:** Validate exactly which Codex auth storage modes permit true managed-home isolation, and downgrade unsupported setups explicitly.
- **Cross-home resume reliability:** Confirm whether session-ID resume behaves consistently after account or home changes on the target Codex CLI version.
- **Unmanaged CLI interoperability:** Decide during planning whether v1 supports only CodeRelay-launched sessions for one-click restart or adds a limited handoff path for external terminals.
- **Codex App path:** Do not infer implementation from CLI behavior; treat app restart and resume as a separate validation effort with its own success criteria.

## Sources

### Primary (HIGH confidence)
- `CodeRelay/.planning/research/STACK.md` — native stack, module split, storage, and distribution guidance.
- `CodeRelay/.planning/research/FEATURES.md` — table stakes, differentiators, and anti-features.
- `CodeRelay/.planning/research/ARCHITECTURE.md` — component boundaries, runtime model, and suggested build order.
- `CodeRelay/.planning/research/PITFALLS.md` — failure modes, prevention strategies, and phase warnings.
- CodexBar docs and source referenced by the research set — managed homes, reconciliation, scoped probing, and menu bar patterns.
- OpenAI Codex CLI docs and local CLI validation referenced by the research set — `resume`, `app-server`, and auth semantics.

### Secondary (MEDIUM confidence)
- cc-switch docs and Rust source referenced by the research set — transaction and rollback plus session-restore patterns, but broader product scope than CodeRelay.
- OpenAI Codex releases and issues referenced by the research set — useful for resume-stability caveats, not an architecture source of truth.

---
*Research completed: 2026-04-01*
*Ready for roadmap: yes*
